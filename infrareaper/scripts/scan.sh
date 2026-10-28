#!/usr/bin/env bash
# ============================================================
# InfraReaper Resource Scanner (scan.sh)
# ============================================================
# Scans targeted Azure Resource Groups for deployed resources,
# identifies orphaned assets (unattached disks, unused IPs,
# unattached NICs), and exports a normalized JSON inventory.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

INVENTORY_FILE="${OUTPUT_DIR}/inventory.json"
TEMP_RAW_DIR="${OUTPUT_DIR}/raw"
mkdir -p "${TEMP_RAW_DIR}"

log_info "=== Starting InfraReaper Resource Scan ==="
check_dependencies
azure_login

# ------------------------------------------------------------
# Determine Target Resource Groups
# ------------------------------------------------------------
TARGET_RGS=()
if [[ "${TARGET_RESOURCE_GROUPS}" == "ALL" ]]; then
    log_info "Scanning ALL accessible Resource Groups..."
    while IFS= read -r rg; do
        [[ -n "${rg}" ]] && TARGET_RGS+=("${rg}")
    done < <(az group list --query "[].name" -o tsv)
else
    # Parse space or comma-separated list
    IFS=', ' read -r -a TARGET_RGS <<< "${TARGET_RESOURCE_GROUPS}"
fi

log_info "Target Resource Groups (${#TARGET_RGS[@]}): ${TARGET_RGS[*]}"

# ------------------------------------------------------------
# Scan Resources
# ------------------------------------------------------------
ALL_RESOURCES_TEMP="${TEMP_RAW_DIR}/all_resources.json"
echo "[]" > "${ALL_RESOURCES_TEMP}"

for rg in "${TARGET_RGS[@]}"; do
    log_info "Scanning Resource Group: ${rg}..."

    # Check if resource group exists
    if ! az group show --name "${rg}" &>/dev/null; then
        log_warn "Resource Group '${rg}' not found or inaccessible. Skipping."
        continue
    fi

    # 1. Collect standard Azure resources
    log_debug "Querying standard resources in ${rg}..."
    RAW_RES_FILE="${TEMP_RAW_DIR}/${rg}_resources.json"
    az resource list --resource-group "${rg}" -o json > "${RAW_RES_FILE}" 2>/dev/null || echo "[]" > "${RAW_RES_FILE}"

    # 2. Query unattached managed disks
    log_debug "Querying unattached disks in ${rg}..."
    RAW_DISKS_FILE="${TEMP_RAW_DIR}/${rg}_disks.json"
    az disk list --resource-group "${rg}" --query "[?managedBy==null]" -o json > "${RAW_DISKS_FILE}" 2>/dev/null || echo "[]" > "${RAW_DISKS_FILE}"

    # 3. Query unassociated public IPs
    log_debug "Querying unassociated public IPs in ${rg}..."
    RAW_IPS_FILE="${TEMP_RAW_DIR}/${rg}_ips.json"
    az network public-ip list --resource-group "${rg}" --query "[?ipConfiguration==null]" -o json > "${RAW_IPS_FILE}" 2>/dev/null || echo "[]" > "${RAW_IPS_FILE}"

    # 4. Query unattached network interfaces (NICs without VM)
    log_debug "Querying unattached NICs in ${rg}..."
    RAW_NICS_FILE="${TEMP_RAW_DIR}/${rg}_nics.json"
    az network nic list --resource-group "${rg}" --query "[?virtualMachine==null]" -o json > "${RAW_NICS_FILE}" 2>/dev/null || echo "[]" > "${RAW_NICS_FILE}"

    # Normalize and merge resources for this RG
    MERGED_RG_FILE="${TEMP_RAW_DIR}/${rg}_merged.json"
    SCAN_TIME="$(_timestamp)"

    jq -n \
        --arg scan_time "${SCAN_TIME}" \
        --arg rg "${rg}" \
        --slurpfile standard "${RAW_RES_FILE}" \
        --slurpfile unattached_disks "${RAW_DISKS_FILE}" \
        --slurpfile unassociated_ips "${RAW_IPS_FILE}" \
        --slurpfile unattached_nics "${RAW_NICS_FILE}" \
        '
        ($unattached_disks[0] // [] | map(.id | ascii_downcase)) as $orphan_disk_ids |
        ($unassociated_ips[0] // [] | map(.id | ascii_downcase)) as $orphan_ip_ids |
        ($unattached_nics[0] // [] | map(.id | ascii_downcase)) as $orphan_nic_ids |

        ($standard[0] // []) | map({
            id: .id,
            name: .name,
            type: .type,
            resourceGroup: ($rg),
            location: .location,
            tags: (.tags // {}),
            is_orphan: (
                (.id | ascii_downcase) as $item_id |
                ($orphan_disk_ids | index($item_id)) != null or
                ($orphan_ip_ids | index($item_id)) != null or
                ($orphan_nic_ids | index($item_id)) != null
            ),
            orphan_type: (
                (.id | ascii_downcase) as $item_id |
                if ($orphan_disk_ids | index($item_id)) != null then "unattached_disk"
                elif ($orphan_ip_ids | index($item_id)) != null then "unassociated_public_ip"
                elif ($orphan_nic_ids | index($item_id)) != null then "unattached_nic"
                else null end
            ),
            created_time: (.createdTime // null),
            scanned_at: $scan_time
        })
        ' > "${MERGED_RG_FILE}"

    # Append to cumulative list
    jq -s 'add' "${ALL_RESOURCES_TEMP}" "${MERGED_RG_FILE}" > "${ALL_RESOURCES_TEMP}.tmp"
    mv "${ALL_RESOURCES_TEMP}.tmp" "${ALL_RESOURCES_TEMP}"
done

# ------------------------------------------------------------
# Generate Final Inventory Report
# ------------------------------------------------------------
TOTAL_COUNT=$(jq 'length' "${ALL_RESOURCES_TEMP}")
ORPHAN_COUNT=$(jq '[.[] | select(.is_orphan == true)] | length' "${ALL_RESOURCES_TEMP}")
TIMESTAMP="$(_timestamp)"

jq -n \
    --arg timestamp "${TIMESTAMP}" \
    --argjson total "${TOTAL_COUNT}" \
    --argjson orphans "${ORPHAN_COUNT}" \
    --slurpfile rgs <(printf '%s\n' "${TARGET_RGS[@]}" | jq -R . | jq -s .) \
    --slurpfile resources "${ALL_RESOURCES_TEMP}" \
    '{
        metadata: {
            scanned_at: $timestamp,
            target_resource_groups: $rgs[0],
            total_resources: $total,
            orphan_count: $orphans
        },
        resources: $resources[0]
    }' > "${INVENTORY_FILE}"

# Cleanup temp files
rm -rf "${TEMP_RAW_DIR}"

log_success "=== Scan Complete ==="
log_info "Total Resources Found: ${TOTAL_COUNT}"
log_info "Orphaned Assets Found: ${ORPHAN_COUNT}"
log_info "Inventory saved to: ${INVENTORY_FILE}"
