#!/usr/bin/env bash
# ============================================================
# InfraReaper Safe Resource Cleanup Engine (cleanup.sh)
# ============================================================
# Safely deallocates and purges expired resources past their grace
# period and orphaned cloud assets, enforcing strict whitelist
# protection and Azure resource locks.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

LIFECYCLE_FILE="${OUTPUT_DIR}/lifecycle-report.json"
AUDIT_FILE="${OUTPUT_DIR}/cleanup-audit.json"
PROTECTED_CONFIG="${PROTECTED_CONFIG:-${SCRIPT_DIR}/../policies/protected-resources.yaml}"

# Safety boundaries: cleanup can ONLY touch this resource group
ALLOWED_CLEANUP_RGS=("infrareaper-test-resources")
PROTECTED_RGS=("infrareaper-core-rg" "infrareaper-state-rg" "NetworkWatcherRG")

log_info "=== Starting InfraReaper Cleanup Engine ==="
log_info "Execution Mode: DRY_RUN = ${DRY_RUN}"

if [[ ! -f "${LIFECYCLE_FILE}" ]]; then
    log_error "Lifecycle report not found: ${LIFECYCLE_FILE}"
    log_error "Please run check-expiry.sh first."
    exit 1
fi

# Optional: Switch to Cleanup Service Principal if provided
if [[ -n "${CLEANUP_CLIENT_ID:-}" && -n "${CLEANUP_CLIENT_SECRET:-}" && -n "${CLEANUP_TENANT_ID:-}" ]]; then
    log_info "Authenticating with dedicated Cleanup Service Principal..."
    azure_login "${CLEANUP_CLIENT_ID}" "${CLEANUP_CLIENT_SECRET}" "${CLEANUP_TENANT_ID}"
fi

AUDIT_ACTIONS_TEMP="${OUTPUT_DIR}/temp_audit_actions.json"
echo "[]" > "${AUDIT_ACTIONS_TEMP}"

# Extract all resources flagged as actionable
CANDIDATES_JSON=$(jq -c '[.resources[] | select(.actionable_for_cleanup == true)]' "${LIFECYCLE_FILE}")
CANDIDATE_COUNT=$(echo "${CANDIDATES_JSON}" | jq 'length')

log_info "Discovered ${CANDIDATE_COUNT} candidate resources eligible for cleanup."

for (( i=0; i<CANDIDATE_COUNT; i++ )); do
    RES=$(echo "${CANDIDATES_JSON}" | jq -c ".[$i]")
    RES_ID=$(echo "${RES}" | jq -r '.id')
    RES_NAME=$(echo "${RES}" | jq -r '.name')
    RES_TYPE=$(echo "${RES}" | jq -r '.type')
    RES_RG=$(echo "${RES}" | jq -r '.resourceGroup')
    IS_ORPHAN=$(echo "${RES}" | jq -r '.is_orphan')
    ORPHAN_TYPE=$(echo "${RES}" | jq -r '.orphan_type // empty')
    ACTION_STATUS=""
    ACTION_REASON=""

    # --------------------------------------------------------
    # Safety Check 1: Protected Resource Groups Whitelist
    # --------------------------------------------------------
    IS_PROTECTED_RG=false
    for prg in "${PROTECTED_RGS[@]}"; do
        if [[ "${RES_RG,,}" == "${prg,,}" ]]; then
            IS_PROTECTED_RG=true
            break
        fi
    done

    if [[ "${IS_PROTECTED_RG}" == "true" ]]; then
        log_warn "[SAFETY GUARD] Resource '${RES_NAME}' belongs to protected RG '${RES_RG}'. Deletion DENIED."
        ACTION_STATUS="PROTECTED_RG_SKIPPED"
        ACTION_REASON="Resource group is in protected infrastructure whitelist"
    fi

    # --------------------------------------------------------
    # Safety Check 2: Allowed Target Boundary
    # --------------------------------------------------------
    if [[ -z "${ACTION_STATUS}" ]]; then
        IS_ALLOWED_RG=false
        for arg in "${ALLOWED_CLEANUP_RGS[@]}"; do
            if [[ "${RES_RG,,}" == "${arg,,}" ]]; then
                IS_ALLOWED_RG=true
                break
            fi
        done

        if [[ "${IS_ALLOWED_RG}" == "false" ]]; then
            log_warn "[SAFETY GUARD] Resource '${RES_NAME}' RG '${RES_RG}' is outside allowed cleanup targets. Deletion DENIED."
            ACTION_STATUS="UNAUTHORIZED_RG_SKIPPED"
            ACTION_REASON="Target resource group is not within allowed cleanup scopes"
        fi
    fi

    # --------------------------------------------------------
    # Safety Check 3: Protected Resource Types & Protected Tags
    # --------------------------------------------------------
    if [[ -z "${ACTION_STATUS}" ]]; then
        PROTECTED_TYPES=(
            "Microsoft.ContainerService/managedClusters"
            "Microsoft.ContainerRegistry/registries"
            "Microsoft.KeyVault/vaults"
            "Microsoft.OperationalInsights/workspaces"
        )
        for ptype in "${PROTECTED_TYPES[@]}"; do
            if [[ "${RES_TYPE}" == "${ptype}" ]]; then
                log_warn "[SAFETY GUARD] Resource '${RES_NAME}' has protected type '${RES_TYPE}'. Deletion DENIED."
                ACTION_STATUS="PROTECTED_TYPE_SKIPPED"
                ACTION_REASON="Resource type is core platform infrastructure"
                break
            fi
        done

        # Check tags for protected flag
        IS_PROTECTED_TAG=$(echo "${RES}" | jq -r '
            .tags // {} | to_entries[] |
            select((.key | ascii_downcase) == "protected" and (.value | ascii_downcase) == "true" or
                   (.key | ascii_downcase) == "do-not-delete" and (.value | ascii_downcase) == "true") |
            .key
        ' 2>/dev/null | head -n 1)

        if [[ -n "${IS_PROTECTED_TAG}" ]]; then
            log_warn "[SAFETY GUARD] Resource '${RES_NAME}' has protected tag '${IS_PROTECTED_TAG}'. Deletion DENIED."
            ACTION_STATUS="PROTECTED_TAG_SKIPPED"
            ACTION_REASON="Resource is annotated with protected/do-not-delete tag"
        fi
    fi

    # --------------------------------------------------------
    # Safety Check 4: Azure Resource Locks
    # --------------------------------------------------------
    if [[ -z "${ACTION_STATUS}" ]]; then
        LOCK_COUNT=$(az lock list --resource-group "${RES_RG}" --resource "${RES_NAME}" --resource-type "${RES_TYPE}" --query "length(@)" -o tsv 2>/dev/null || echo "0")
        if [[ "${LOCK_COUNT}" -gt 0 ]]; then
            log_warn "[SAFETY GUARD] Resource '${RES_NAME}' has an active Azure resource lock. Deletion SKIPPED."
            ACTION_STATUS="RESOURCE_LOCKED_SKIPPED"
            ACTION_REASON="Azure CanNotDelete or ReadOnly lock active on resource"
        fi
    fi

    # --------------------------------------------------------
    # Perform Execution (Dry-Run vs Real Execution)
    # --------------------------------------------------------
    if [[ -z "${ACTION_STATUS}" ]]; then
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "[DRY RUN] Would deallocate/purge ${RES_TYPE} '${RES_NAME}' (RG: ${RES_RG})"
            ACTION_STATUS="DRY_RUN_DELETE_SIMULATED"
            ACTION_REASON="Resource expired past grace period or orphaned; action simulated in dry-run mode"
        else
            log_warn "Executing automated cleanup for ${RES_TYPE} '${RES_NAME}'..."
            EXEC_SUCCESS=true

            # Step A: Graceful deallocation if Virtual Machine
            if [[ "${RES_TYPE}" == "Microsoft.Compute/virtualMachines" ]]; then
                log_info "Deallocating Virtual Machine '${RES_NAME}' before deletion..."
                az vm deallocate --resource-group "${RES_RG}" --name "${RES_NAME}" --no-wait 2>/dev/null || true
                sleep 5
            fi

            # Step B: Resource deletion
            DEL_ERR=""
            if [[ "${RES_TYPE}" == "Microsoft.Storage/storageAccounts" ]]; then
                DEL_ERR=$(az storage account delete --name "${RES_NAME}" --resource-group "${RES_RG}" --yes 2>&1) || EXEC_SUCCESS=false
            elif [[ "${RES_TYPE}" == "Microsoft.Network/publicIPAddresses" ]]; then
                DEL_ERR=$(az network public-ip delete --name "${RES_NAME}" --resource-group "${RES_RG}" 2>&1) || EXEC_SUCCESS=false
            elif [[ "${RES_TYPE}" == "Microsoft.Compute/disks" ]]; then
                DEL_ERR=$(az disk delete --name "${RES_NAME}" --resource-group "${RES_RG}" --yes --no-wait 2>&1) || EXEC_SUCCESS=false
            else
                DEL_ERR=$(az resource delete --ids "${RES_ID}" 2>&1) || EXEC_SUCCESS=false
            fi

            if [[ "${EXEC_SUCCESS}" == "true" ]]; then
                log_success "Successfully deleted resource '${RES_NAME}'."
                ACTION_STATUS="DELETED"
                ACTION_REASON="Expired or orphaned resource successfully deleted"
            else
                log_error "Failed to delete resource '${RES_NAME}'."
                if [[ -n "${DEL_ERR}" ]]; then
                    log_error "Azure Error Output: ${DEL_ERR}"
                fi
                ACTION_STATUS="DELETE_FAILED"
                ACTION_REASON="Azure ARM error: ${DEL_ERR:-Unknown error}"
            fi
        fi
    fi

    # Record action in audit log
    ACTION_RECORD=$(jq -n \
        --arg id "${RES_ID}" \
        --arg name "${RES_NAME}" \
        --arg type "${RES_TYPE}" \
        --arg rg "${RES_RG}" \
        --arg is_orphan "${IS_ORPHAN}" \
        --arg orphan_type "${ORPHAN_TYPE}" \
        --arg status "${ACTION_STATUS}" \
        --arg reason "${ACTION_REASON}" \
        --arg timestamp "$(_timestamp)" \
        '{
            resource_id: $id,
            resource_name: $name,
            resource_type: $type,
            resource_group: $rg,
            is_orphan: ($is_orphan == "true"),
            orphan_type: (if $orphan_type == "" then null else $orphan_type end),
            action_status: $status,
            action_reason: $reason,
            timestamp: $timestamp
        }')

    jq --argjson item "${ACTION_RECORD}" '. += [$item]' "${AUDIT_ACTIONS_TEMP}" > "${AUDIT_ACTIONS_TEMP}.tmp"
    mv "${AUDIT_ACTIONS_TEMP}.tmp" "${AUDIT_ACTIONS_TEMP}"
done

# ------------------------------------------------------------
# Generate Final Audit Report
# ------------------------------------------------------------
jq \
    --arg dry_run "${DRY_RUN}" \
    --arg timestamp "$(_timestamp)" \
    --slurpfile actions "${AUDIT_ACTIONS_TEMP}" \
    '
    ($actions[0]) as $items |
    {
        audit_metadata: {
            timestamp: $timestamp,
            dry_run: ($dry_run == "true"),
            total_candidates: ($items | length),
            deleted_count: ([$items[] | select(.action_status == "DELETED")] | length),
            dry_run_simulated_count: ([$items[] | select(.action_status == "DRY_RUN_DELETE_SIMULATED")] | length),
            skipped_protected_count: ([$items[] | select(.action_status | test("SKIPPED"))] | length),
            failed_count: ([$items[] | select(.action_status == "DELETE_FAILED")] | length)
        },
        actions: $items
    }
    ' "${AUDIT_ACTIONS_TEMP}" > "${AUDIT_FILE}"

rm -f "${AUDIT_ACTIONS_TEMP}"

SIM_CNT=$(jq '.audit_metadata.dry_run_simulated_count' "${AUDIT_FILE}")
DEL_CNT=$(jq '.audit_metadata.deleted_count' "${AUDIT_FILE}")
SKIP_CNT=$(jq '.audit_metadata.skipped_protected_count' "${AUDIT_FILE}")

log_success "=== Cleanup Run Complete ==="
log_info "Deleted (Real): ${DEL_CNT}"
log_info "Simulated (Dry-Run): ${SIM_CNT}"
log_info "Protected/Locked Skipped: ${SKIP_CNT}"
log_info "Audit Log saved to: ${AUDIT_FILE}"
