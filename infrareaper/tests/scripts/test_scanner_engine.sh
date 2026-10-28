#!/usr/bin/env bash
# ============================================================
# InfraReaper Unit & Integration Test Suite
# ============================================================
# Validates the scanner application logic without needing live
# Azure connectivity by using mock inventories and test fixtures.
# ============================================================

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/../.." && pwd)"
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
TEST_TMP_DIR="${PROJECT_ROOT}/tmp/test-run-$(date +%s)"

mkdir -p "${TEST_TMP_DIR}"

# Cleanup on exit
trap 'rm -rf "${TEST_TMP_DIR}"' EXIT

FAILED_TESTS=0
TOTAL_TESTS=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local description="$3"

    TOTAL_TESTS=$(( TOTAL_TESTS + 1 ))
    if [[ "${expected}" == "${actual}" ]]; then
        echo "  ✓ PASS: ${description}"
    else
        echo "  ✗ FAIL: ${description} (Expected: '${expected}', Got: '${actual}')" >&2
        FAILED_TESTS=$(( FAILED_TESTS + 1 ))
    fi
}

echo "============================================================"
echo "      InfraReaper Scanner Engine - Test Suite              "
echo "============================================================"

# ------------------------------------------------------------
# TEST 1: Policy Evaluation Logic with Mock Inventory
# ------------------------------------------------------------
echo ""
echo "Test Suite 1: Governance Policy Evaluator"

MOCK_INVENTORY="${TEST_TMP_DIR}/inventory.json"
cat <<EOF > "${MOCK_INVENTORY}"
{
  "metadata": {
    "scanned_at": "2026-10-27T00:00:00Z",
    "target_resource_groups": ["infrareaper-test-resources"],
    "total_resources": 4,
    "orphan_count": 1
  },
  "resources": [
    {
      "id": "/subscriptions/sub/resourceGroups/infrareaper-test-resources/providers/Microsoft.Compute/virtualMachines/test-vm-compliant",
      "name": "test-vm-compliant",
      "type": "Microsoft.Compute/virtualMachines",
      "resourceGroup": "infrareaper-test-resources",
      "location": "centralindia",
      "tags": {
        "owner": "santhosh@example.com",
        "environment": "dev",
        "expiry-date": "2026-12-31"
      },
      "is_orphan": false,
      "orphan_type": null
    },
    {
      "id": "/subscriptions/sub/resourceGroups/infrareaper-test-resources/providers/Microsoft.Compute/virtualMachines/test-vm-untagged",
      "name": "test-vm-untagged",
      "type": "Microsoft.Compute/virtualMachines",
      "resourceGroup": "infrareaper-test-resources",
      "location": "centralindia",
      "tags": {},
      "is_orphan": false,
      "orphan_type": null
    },
    {
      "id": "/subscriptions/sub/resourceGroups/infrareaper-test-resources/providers/Microsoft.Storage/storageAccounts/test-storage-expired",
      "name": "test-storage-expired",
      "type": "Microsoft.Storage/storageAccounts",
      "resourceGroup": "infrareaper-test-resources",
      "location": "centralindia",
      "tags": {
        "owner": "santhosh@example.com",
        "environment": "invalid_env",
        "expiry-date": "2026-01-01"
      },
      "is_orphan": false,
      "orphan_type": null
    },
    {
      "id": "/subscriptions/sub/resourceGroups/infrareaper-test-resources/providers/Microsoft.Compute/disks/test-unattached-disk",
      "name": "test-unattached-disk",
      "type": "Microsoft.Compute/disks",
      "resourceGroup": "infrareaper-test-resources",
      "location": "centralindia",
      "tags": {
        "owner": "santhosh@example.com",
        "environment": "dev",
        "expiry-date": "2026-11-30"
      },
      "is_orphan": true,
      "orphan_type": "unattached_disk"
    }
  ]
}
EOF

export OUTPUT_DIR="${TEST_TMP_DIR}"
bash "${SCRIPTS_DIR}/evaluate-policies.sh"

COMPLIANCE_JSON="${TEST_TMP_DIR}/compliance-report.json"

COMPLIANT_CNT=$(jq '.summary.compliant_resources' "${COMPLIANCE_JSON}")
TOTAL_CNT=$(jq '.summary.total_resources' "${COMPLIANCE_JSON}")
CRIT_CNT=$(jq '.summary.violations_by_severity.CRITICAL' "${COMPLIANCE_JSON}")
INFO_CNT=$(jq '.summary.violations_by_severity.INFO' "${COMPLIANCE_JSON}")

assert_equals "2" "${COMPLIANT_CNT}" "Compliant resources count correctly identified (2 out of 4)"
assert_equals "4" "${TOTAL_CNT}" "Total resources count matches mock input"
assert_equals "1" "${CRIT_CNT}" "Critical violation (missing owner) flagged on untagged VM"
assert_equals "1" "${INFO_CNT}" "Invalid environment value flagged as INFO violation"

# ------------------------------------------------------------
# TEST 2: Lifecycle & Expiry Evaluator Logic
# ------------------------------------------------------------
echo ""
echo "Test Suite 2: Lifecycle & Expiry Calculator"

bash "${SCRIPTS_DIR}/check-expiry.sh"
LIFECYCLE_JSON="${TEST_TMP_DIR}/lifecycle-report.json"

EXPIRED_CNT=$(jq '.summary.expired_actionable' "${LIFECYCLE_JSON}")
ACTIONABLE_CNT=$(jq '.summary.actionable_for_cleanup' "${LIFECYCLE_JSON}")

assert_equals "1" "${EXPIRED_CNT}" "Expired storage account flagged as EXPIRED_ACTIONABLE"
# 1 expired storage account + 1 orphan disk = 2 actionable for cleanup
assert_equals "2" "${ACTIONABLE_CNT}" "Total actionable resources identified for cleanup (expired + orphan)"

# ------------------------------------------------------------
# TEST 3: Cleanup Safety Whitelist Verification
# ------------------------------------------------------------
echo ""
echo "Test Suite 3: Protected Resources Whitelist Safety Guard"

export DRY_RUN="true"
bash "${SCRIPTS_DIR}/cleanup.sh"
AUDIT_JSON="${TEST_TMP_DIR}/cleanup-audit.json"

SIMULATED_DELETES=$(jq '.audit_metadata.dry_run_simulated_count' "${AUDIT_JSON}")
FAILED_CLEANUPS=$(jq '.audit_metadata.failed_count' "${AUDIT_JSON}")

assert_equals "2" "${SIMULATED_DELETES}" "Dry run simulated deletion for actionable items without mutating Azure"
assert_equals "0" "${FAILED_CLEANUPS}" "No unhandled cleanup errors during execution"

# ------------------------------------------------------------
# TEST 4: Prometheus Metrics Formatting Check
# ------------------------------------------------------------
echo ""
echo "Test Suite 4: Prometheus Metrics Exposition Generation"

export PUSHGATEWAY_URL="http://127.0.0.1:9099" # Intentional unreachable port for non-fatal check
bash "${SCRIPTS_DIR}/push-metrics.sh"
METRICS_FILE="${TEST_TMP_DIR}/metrics.prom"

HAS_TOTAL_METRIC=$(grep -c "infrareaper_resources_total" "${METRICS_FILE}" || true)
HAS_SCORE_METRIC=$(grep -c "infrareaper_compliance_score" "${METRICS_FILE}" || true)

assert_equals "2" "${HAS_TOTAL_METRIC}" "Prometheus help and gauge present for infrareaper_resources_total"
assert_equals "2" "${HAS_SCORE_METRIC}" "Prometheus help and gauge present for infrareaper_compliance_score"

echo ""
echo "============================================================"
if [[ ${FAILED_TESTS} -eq 0 ]]; then
    echo "  ALL ${TOTAL_TESTS} TESTS PASSED SUCCESSFULLY! ✓"
    echo "============================================================"
    exit 0
else
    echo "  ${FAILED_TESTS} of ${TOTAL_TESTS} TESTS FAILED!"
    echo "============================================================"
    exit 1
fi

