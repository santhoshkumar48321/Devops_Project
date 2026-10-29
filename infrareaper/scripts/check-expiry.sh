#!/usr/bin/env bash
# ============================================================
# InfraReaper Lifecycle & Expiry Evaluator (check-expiry.sh)
# ============================================================
# Evaluates resource expiration timestamps against lifecycle policies.
# Classifies resources into states: ACTIVE, EXPIRING_7D, EXPIRING_72H,
# EXPIRING_24H, EXPIRED_IN_GRACE, and EXPIRED_ACTIONABLE.
# Enforces strict Untagged Quarantine for non-compliant resources.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

COMPLIANCE_FILE="${OUTPUT_DIR}/compliance-report.json"
LIFECYCLE_FILE="${OUTPUT_DIR}/lifecycle-report.json"

log_info "=== Starting Lifecycle & Expiry Evaluation ==="

if [[ ! -f "${COMPLIANCE_FILE}" ]]; then
    log_error "Compliance report not found: ${COMPLIANCE_FILE}"
    log_error "Please run evaluate-policies.sh first."
    exit 1
fi

NOW_EPOCH=$(date -u +%s)
EVALUATED_AT="$(_timestamp)"
DEFAULT_TTL_DAYS=30
GRACE_PERIOD_HOURS=48
GRACE_PERIOD_SECONDS=$(( GRACE_PERIOD_HOURS * 3600 ))
UNTAGGED_TTL_HOURS="${UNTAGGED_TTL_HOURS:-0}"

# Helper script for jq to parse and categorize dates
TEMP_EVAL_FILE="${OUTPUT_DIR}/temp_lifecycle_resources.json"
echo "[]" > "${TEMP_EVAL_FILE}"

RESOURCE_COUNT=$(jq '.resources | length' "${COMPLIANCE_FILE}")
log_info "Evaluating lifecycle for ${RESOURCE_COUNT} resources..."

for (( i=0; i<RESOURCE_COUNT; i++ )); do
    RES_JSON=$(jq -c ".resources[$i]" "${COMPLIANCE_FILE}")
    RES_NAME=$(echo "${RES_JSON}" | jq -r '.name')
    EXPIRY_DATE=$(echo "${RES_JSON}" | jq -r '.expiry_date // empty')
    IS_ORPHAN=$(echo "${RES_JSON}" | jq -r '.is_orphan')
    IS_COMPLIANT=$(echo "${RES_JSON}" | jq -r '.is_compliant // true')
    HAS_CRITICAL=$(echo "${RES_JSON}" | jq '[.violations[]? | select(.severity == "CRITICAL")] | length > 0')

    EXPIRY_EPOCH=0
    EFFECTIVE_EXPIRY_DATE=""
    IS_UNTAGGED_QUARANTINE=false

    if [[ -n "${EXPIRY_DATE}" && "${EXPIRY_DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        # Case 1: Resource has an explicit expiry-date tag (at 23:59:59 UTC)
        if date -u -d "${EXPIRY_DATE} 23:59:59" +%s &>/dev/null; then
            EXPIRY_EPOCH=$(date -u -d "${EXPIRY_DATE} 23:59:59" +%s)
        else
            # BusyBox / BSD date fallback
            EXPIRY_EPOCH=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "${EXPIRY_DATE} 23:59:59" +%s 2>/dev/null || echo "$(( NOW_EPOCH + 86400 * DEFAULT_TTL_DAYS ))")
        fi
        EFFECTIVE_EXPIRY_DATE="${EXPIRY_DATE}"
    elif [[ "${IS_COMPLIANT}" == "false" || "${HAS_CRITICAL}" == "true" ]]; then
        # Case 2: Untagged or policy-violating resource in sandbox/dev environment
        # Enforce Untagged Quarantine Policy: non-compliant resources do NOT receive a 30-day lease!
        IS_UNTAGGED_QUARANTINE=true
        if [[ "${UNTAGGED_TTL_HOURS}" -eq 0 ]]; then
            # Immediate expiration past grace period
            EXPIRY_EPOCH=$(( NOW_EPOCH - (GRACE_PERIOD_SECONDS + 3600) ))
            EFFECTIVE_EXPIRY_DATE="untagged-quarantine-expired"
            log_info "Resource '${RES_NAME}' is UNTAGGED/NON-COMPLIANT. Action: Immediate quarantine expiration."
        else
            EXPIRY_EPOCH=$(( NOW_EPOCH + UNTAGGED_TTL_HOURS * 3600 ))
            EFFECTIVE_EXPIRY_DATE="untagged-quarantine-${UNTAGGED_TTL_HOURS}h"
            log_info "Resource '${RES_NAME}' is UNTAGGED/NON-COMPLIANT. Action: ${UNTAGGED_TTL_HOURS}h quarantine window."
        fi
    else
        # Case 3: Compliant resource without an explicit expiry tag: apply default 30-day lease
        EXPIRY_EPOCH=$(( NOW_EPOCH + 86400 * DEFAULT_TTL_DAYS ))
        EFFECTIVE_EXPIRY_DATE=$(date -u -d "@${EXPIRY_EPOCH}" +"%Y-%m-%d" 2>/dev/null || date -u -r "${EXPIRY_EPOCH}" +"%Y-%m-%d" 2>/dev/null || echo "default-ttl-applied")
    fi

    DELTA_SECONDS=$(( EXPIRY_EPOCH - NOW_EPOCH ))
    LIFECYCLE_STATE="ACTIVE"
    ACTIONABLE_FOR_CLEANUP=false

    if [[ "${IS_UNTAGGED_QUARANTINE}" == "true" && ${DELTA_SECONDS} -le 0 ]]; then
        # Non-compliant untagged resources past quarantine window are actionable immediately
        LIFECYCLE_STATE="EXPIRED_ACTIONABLE"
        ACTIONABLE_FOR_CLEANUP=true
    elif [[ ${DELTA_SECONDS} -gt 604800 ]]; then
        LIFECYCLE_STATE="ACTIVE"
    elif [[ ${DELTA_SECONDS} -le 604800 && ${DELTA_SECONDS} -gt 259200 ]]; then
        LIFECYCLE_STATE="EXPIRING_7D"
    elif [[ ${DELTA_SECONDS} -le 259200 && ${DELTA_SECONDS} -gt 86400 ]]; then
        LIFECYCLE_STATE="EXPIRING_72H"
    elif [[ ${DELTA_SECONDS} -le 86400 && ${DELTA_SECONDS} -ge 0 ]]; then
        LIFECYCLE_STATE="EXPIRING_24H"
    else
        # Resource is past its expiration date
        EXPIRED_PAST_SECONDS=$(( -DELTA_SECONDS ))
        if [[ ${EXPIRED_PAST_SECONDS} -le ${GRACE_PERIOD_SECONDS} && "${IS_COMPLIANT}" == "true" ]]; then
            LIFECYCLE_STATE="EXPIRED_IN_GRACE"
        else
            LIFECYCLE_STATE="EXPIRED_ACTIONABLE"
            ACTIONABLE_FOR_CLEANUP=true
        fi
    fi

    # Orphaned resources (unattached disks, IPs, NICs, NSGs) are automatically actionable
    if [[ "${IS_ORPHAN}" == "true" ]]; then
        ACTIONABLE_FOR_CLEANUP=true
    fi

    # Append augmented resource record
    UPDATED_RES=$(echo "${RES_JSON}" | jq \
        --arg state "${LIFECYCLE_STATE}" \
        --arg eff_exp "${EFFECTIVE_EXPIRY_DATE}" \
        --argjson exp_epoch "${EXPIRY_EPOCH}" \
        --argjson delta "${DELTA_SECONDS}" \
        --argjson actionable "${ACTIONABLE_FOR_CLEANUP}" \
        '. + {
            lifecycle_state: $state,
            effective_expiry_date: $eff_exp,
            expiry_epoch: $exp_epoch,
            time_to_expiry_seconds: $delta,
            actionable_for_cleanup: $actionable
        }')

    jq --argjson item "${UPDATED_RES}" '. += [$item]' "${TEMP_EVAL_FILE}" > "${TEMP_EVAL_FILE}.tmp"
    mv "${TEMP_EVAL_FILE}.tmp" "${TEMP_EVAL_FILE}"
done

# ------------------------------------------------------------
# Generate Final Lifecycle Report
# ------------------------------------------------------------
jq \
    --arg evaluated_at "${EVALUATED_AT}" \
    --slurpfile items "${TEMP_EVAL_FILE}" \
    '
    ($items[0]) as $resources |
    ($resources | length) as $total |

    {
        summary: {
            evaluated_at: $evaluated_at,
            total_resources: $total,
            active: ([$resources[] | select(.lifecycle_state == "ACTIVE")] | length),
            expiring_7d: ([$resources[] | select(.lifecycle_state == "EXPIRING_7D")] | length),
            expiring_72h: ([$resources[] | select(.lifecycle_state == "EXPIRING_72H")] | length),
            expiring_24h: ([$resources[] | select(.lifecycle_state == "EXPIRING_24H")] | length),
            expired_in_grace: ([$resources[] | select(.lifecycle_state == "EXPIRED_IN_GRACE")] | length),
            expired_actionable: ([$resources[] | select(.lifecycle_state == "EXPIRED_ACTIONABLE")] | length),
            actionable_for_cleanup: ([$resources[] | select(.actionable_for_cleanup == true)] | length)
        },
        resources: $resources
    }
    ' "${TEMP_EVAL_FILE}" > "${LIFECYCLE_FILE}"

rm -f "${TEMP_EVAL_FILE}"

TOTAL_EVAL=$(jq '.summary.total_resources' "${LIFECYCLE_FILE}")
ACTIVE_CNT=$(jq '.summary.active' "${LIFECYCLE_FILE}")
WARN_CNT=$(jq '(.summary.expiring_7d + .summary.expiring_72h + .summary.expiring_24h)' "${LIFECYCLE_FILE}")
GRACE_CNT=$(jq '.summary.expired_in_grace' "${LIFECYCLE_FILE}")
CLEANUP_CNT=$(jq '.summary.actionable_for_cleanup' "${LIFECYCLE_FILE}")

log_success "=== Lifecycle Evaluation Complete ==="
log_info "Total Resources Evaluated: ${TOTAL_EVAL}"
log_info "Active: ${ACTIVE_CNT}"
log_info "Expiring Soon (Warnings): ${WARN_CNT}"
log_info "Expired (In 48h Grace Period): ${GRACE_CNT}"
log_info "Actionable for Cleanup: ${CLEANUP_CNT}"
log_info "Report saved to: ${LIFECYCLE_FILE}"
