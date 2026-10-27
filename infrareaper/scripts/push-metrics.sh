#!/usr/bin/env bash
# ============================================================
# InfraReaper Prometheus Metrics Exporter (push-metrics.sh)
# ============================================================
# Formats scan and compliance outcomes into Prometheus exposition
# format and pushes them to Prometheus Pushgateway.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

COMPLIANCE_FILE="${OUTPUT_DIR}/compliance-report.json"
LIFECYCLE_FILE="${OUTPUT_DIR}/lifecycle-report.json"
AUDIT_FILE="${OUTPUT_DIR}/cleanup-audit.json"

PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://localhost:9091}"
JOB_NAME="${JOB_NAME:-infrareaper-scanner}"
INSTANCE_NAME="${INSTANCE_NAME:-aks-${ENVIRONMENT}}"
SCAN_DURATION="${SCAN_DURATION:-0}"
SCAN_SUCCESS="${SCAN_SUCCESS:-1}"

log_info "=== Starting Prometheus Metrics Export ==="

# Read metrics from reports or fallback to zero
TOTAL_RES=0
COMPLIANT_RES=0
NON_COMPLIANT_RES=0
COMPLIANCE_SCORE=0
CRIT_VIOL=0
WARN_VIOL=0
INFO_VIOL=0

if [[ -f "${COMPLIANCE_FILE}" ]]; then
    TOTAL_RES=$(jq '.summary.total_resources // 0' "${COMPLIANCE_FILE}")
    COMPLIANT_RES=$(jq '.summary.compliant_resources // 0' "${COMPLIANCE_FILE}")
    NON_COMPLIANT_RES=$(jq '.summary.non_compliant_resources // 0' "${COMPLIANCE_FILE}")
    COMPLIANCE_SCORE=$(jq '.summary.compliance_score // 0' "${COMPLIANCE_FILE}")
    CRIT_VIOL=$(jq '.summary.violations_by_severity.CRITICAL // 0' "${COMPLIANCE_FILE}")
    WARN_VIOL=$(jq '.summary.violations_by_severity.WARNING // 0' "${COMPLIANCE_FILE}")
    INFO_VIOL=$(jq '.summary.violations_by_severity.INFO // 0' "${COMPLIANCE_FILE}")
fi

EXP_7D=0
EXP_72H=0
EXP_24H=0
EXP_GRACE=0
EXP_ACTIONABLE=0
ORPHAN_COUNT=0

if [[ -f "${LIFECYCLE_FILE}" ]]; then
    EXP_7D=$(jq '.summary.expiring_7d // 0' "${LIFECYCLE_FILE}")
    EXP_72H=$(jq '.summary.expiring_72h // 0' "${LIFECYCLE_FILE}")
    EXP_24H=$(jq '.summary.expiring_24h // 0' "${LIFECYCLE_FILE}")
    EXP_GRACE=$(jq '.summary.expired_in_grace // 0' "${LIFECYCLE_FILE}")
    EXP_ACTIONABLE=$(jq '.summary.expired_actionable // 0' "${LIFECYCLE_FILE}")
    ORPHAN_COUNT=$(jq '[.resources[] | select(.is_orphan == true)] | length' "${LIFECYCLE_FILE}")
fi

CLEANED_REAL=0
CLEANED_SIM=0
if [[ -f "${AUDIT_FILE}" ]]; then
    CLEANED_REAL=$(jq '.audit_metadata.deleted_count // 0' "${AUDIT_FILE}")
    CLEANED_SIM=$(jq '.audit_metadata.dry_run_simulated_count // 0' "${AUDIT_FILE}")
fi

# ------------------------------------------------------------
# Build Prometheus Exposition Payload
# ------------------------------------------------------------
METRICS_PAYLOAD=$(cat <<EOF
# HELP infrareaper_scan_total Total number of scans executed
# TYPE infrareaper_scan_total counter
infrareaper_scan_total{environment="${ENVIRONMENT}"} 1

# HELP infrareaper_scan_success_total Total successful scans executed (for 99% SLO)
# TYPE infrareaper_scan_success_total counter
infrareaper_scan_success_total{environment="${ENVIRONMENT}"} ${SCAN_SUCCESS}

# HELP infrareaper_scan_duration_seconds Duration of scan execution in seconds
# TYPE infrareaper_scan_duration_seconds gauge
infrareaper_scan_duration_seconds{environment="${ENVIRONMENT}"} ${SCAN_DURATION}

# HELP infrareaper_resources_total Total resources scanned
# TYPE infrareaper_resources_total gauge
infrareaper_resources_total{environment="${ENVIRONMENT}"} ${TOTAL_RES}

# HELP infrareaper_compliant_resources_total Number of policy-compliant resources
# TYPE infrareaper_compliant_resources_total gauge
infrareaper_compliant_resources_total{environment="${ENVIRONMENT}"} ${COMPLIANT_RES}

# HELP infrareaper_noncompliant_resources_total Number of policy-violating resources
# TYPE infrareaper_noncompliant_resources_total gauge
infrareaper_noncompliant_resources_total{environment="${ENVIRONMENT}"} ${NON_COMPLIANT_RES}

# HELP infrareaper_compliance_score Policy compliance score percentage (0-100)
# TYPE infrareaper_compliance_score gauge
infrareaper_compliance_score{environment="${ENVIRONMENT}"} ${COMPLIANCE_SCORE}

# HELP infrareaper_violations_total Total violations categorized by severity
# TYPE infrareaper_violations_total gauge
infrareaper_violations_total{environment="${ENVIRONMENT}",severity="CRITICAL"} ${CRIT_VIOL}
infrareaper_violations_total{environment="${ENVIRONMENT}",severity="WARNING"} ${WARN_VIOL}
infrareaper_violations_total{environment="${ENVIRONMENT}",severity="INFO"} ${INFO_VIOL}

# HELP infrareaper_orphaned_resources_total Total orphaned assets detected
# TYPE infrareaper_orphaned_resources_total gauge
infrareaper_orphaned_resources_total{environment="${ENVIRONMENT}"} ${ORPHAN_COUNT}

# HELP infrareaper_expiring_resources_total Resources expiring within warning windows
# TYPE infrareaper_expiring_resources_total gauge
infrareaper_expiring_resources_total{environment="${ENVIRONMENT}",window="7d"} ${EXP_7D}
infrareaper_expiring_resources_total{environment="${ENVIRONMENT}",window="72h"} ${EXP_72H}
infrareaper_expiring_resources_total{environment="${ENVIRONMENT}",window="24h"} ${EXP_24H}

# HELP infrareaper_expired_resources_total Total expired resources
# TYPE infrareaper_expired_resources_total gauge
infrareaper_expired_resources_total{environment="${ENVIRONMENT}",state="grace_period"} ${EXP_GRACE}
infrareaper_expired_resources_total{environment="${ENVIRONMENT}",state="actionable"} ${EXP_ACTIONABLE}

# HELP infrareaper_cleaned_resources_total Resources purged during cleanup
# TYPE infrareaper_cleaned_resources_total gauge
infrareaper_cleaned_resources_total{environment="${ENVIRONMENT}",mode="real"} ${CLEANED_REAL}
infrareaper_cleaned_resources_total{environment="${ENVIRONMENT}",mode="dry_run"} ${CLEANED_SIM}
EOF
)

# Also save locally for inspection or file-based scraping
echo "${METRICS_PAYLOAD}" > "${OUTPUT_DIR}/metrics.prom"
log_info "Local Prometheus metrics file saved: ${OUTPUT_DIR}/metrics.prom"

# ------------------------------------------------------------
# Push to Prometheus Pushgateway
# ------------------------------------------------------------
TARGET_PUSH_ENDPOINT="${PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}/instance/${INSTANCE_NAME}"
log_info "Pushing metrics to Pushgateway: ${TARGET_PUSH_ENDPOINT}..."

HTTP_CODE=$(echo "${METRICS_PAYLOAD}" | curl --max-time 10 --silent --write-out "%{http_code}" \
    --data-binary @- "${TARGET_PUSH_ENDPOINT}" 2>/dev/null || echo "000")

if [[ "${HTTP_CODE}" == "200" || "${HTTP_CODE}" == "202" ]]; then
    log_success "Successfully pushed metrics to Prometheus Pushgateway (HTTP ${HTTP_CODE})."
else
    # Pushgateway unavailability is non-fatal (NFR-REL-03)
    log_warn "Pushgateway unreachable or returned HTTP ${HTTP_CODE}. Metrics stored locally; scan will not fail."
fi

exit 0
