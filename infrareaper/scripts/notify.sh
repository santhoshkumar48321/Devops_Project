#!/usr/bin/env bash
# ============================================================
# InfraReaper Email Notification Engine (notify.sh)
# ============================================================
# Dispatches consolidated compliance alerts, lifecycle expiry
# warnings, and cleanup audit digests via the SendGrid v3 API.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

COMPLIANCE_FILE="${OUTPUT_DIR}/compliance-report.json"
LIFECYCLE_FILE="${OUTPUT_DIR}/lifecycle-report.json"
AUDIT_FILE="${OUTPUT_DIR}/cleanup-audit.json"

SENDGRID_API_KEY="${SENDGRID_API_KEY:-}"
NOTIFICATION_TO_EMAIL="${NOTIFICATION_TO_EMAIL:-myselfgudboy@gmail.com}"
NOTIFICATION_FROM_EMAIL="${NOTIFICATION_FROM_EMAIL:-myselfgudboy@gmail.com}"

log_info "=== Starting Notification Engine ==="

if [[ ! -f "${COMPLIANCE_FILE}" || ! -f "${LIFECYCLE_FILE}" ]]; then
    log_warn "Reports missing in ${OUTPUT_DIR}. Skipping notification."
    exit 0
fi

# ------------------------------------------------------------
# Extract Notification Digest Metrics
# ------------------------------------------------------------
SCORE=$(jq '.summary.compliance_score' "${COMPLIANCE_FILE}")
TOTAL_RES=$(jq '.summary.total_resources' "${COMPLIANCE_FILE}")
COMPLIANT_RES=$(jq '.summary.compliant_resources' "${COMPLIANCE_FILE}")
CRIT_COUNT=$(jq '.summary.violations_by_severity.CRITICAL' "${COMPLIANCE_FILE}")
WARN_COUNT=$(jq '.summary.violations_by_severity.WARNING' "${COMPLIANCE_FILE}")

EXP_7D=$(jq '.summary.expiring_7d' "${LIFECYCLE_FILE}")
EXP_72H=$(jq '.summary.expiring_72h' "${LIFECYCLE_FILE}")
EXP_24H=$(jq '.summary.expiring_24h' "${LIFECYCLE_FILE}")
ACTIONABLE_COUNT=$(jq '.summary.actionable_for_cleanup' "${LIFECYCLE_FILE}")

DEL_COUNT=0
SIM_COUNT=0
if [[ -f "${AUDIT_FILE}" ]]; then
    DEL_COUNT=$(jq '.audit_metadata.deleted_count // 0' "${AUDIT_FILE}")
    SIM_COUNT=$(jq '.audit_metadata.dry_run_simulated_count // 0' "${AUDIT_FILE}")
fi

SUBJECT="[InfraReaper Alert] Environment: ${ENVIRONMENT^^} | Compliance Score: ${SCORE}%"

# ------------------------------------------------------------
# Generate HTML Email Content
# ------------------------------------------------------------
HTML_BODY="<html><head><style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #333; margin: 0; padding: 20px; background-color: #f7f9fc; }
.container { max-width: 650px; margin: 0 auto; background: #ffffff; border-radius: 8px; border: 1px solid #e1e4e8; overflow: hidden; }
.header { background: #0078d4; color: #ffffff; padding: 20px; text-align: center; }
.content { padding: 24px; }
.metric-box { display: inline-block; width: 45%; margin: 2%; padding: 12px; background: #f1f3f5; border-radius: 6px; text-align: center; vertical-align: top; }
.metric-val { font-size: 24px; font-weight: bold; color: #0078d4; }
.table { width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 13px; }
.table th { background: #f1f3f5; border: 1px solid #dee2e6; padding: 8px; text-align: left; }
.table td { border: 1px solid #dee2e6; padding: 8px; }
.badge-crit { background: #d9534f; color: white; padding: 2px 6px; border-radius: 4px; font-size: 11px; }
.badge-warn { background: #f0ad4e; color: white; padding: 2px 6px; border-radius: 4px; font-size: 11px; }
.footer { font-size: 12px; color: #6c757d; text-align: center; padding: 15px; border-top: 1px solid #e1e4e8; }
</style></head><body>
<div class='container'>
  <div class='header'>
    <h2>Infrareaper Cloud Governance Report</h2>
    <p>Target Environment: <strong>${ENVIRONMENT}</strong> | Scan Time: $(_timestamp)</p>
  </div>
  <div class='content'>
    <h3>Scan Overview</h3>
    <div class='metric-box'><div class='metric-val'>${SCORE}%</div><div>Compliance Score</div></div>
    <div class='metric-box'><div class='metric-val'>${COMPLIANT_RES} / ${TOTAL_RES}</div><div>Compliant Assets</div></div>
    <div class='metric-box'><div class='metric-val'>${CRIT_COUNT} / ${WARN_COUNT}</div><div>Violations (Crit/Warn)</div></div>
    <div class='metric-box'><div class='metric-val'>$(( EXP_7D + EXP_72H + EXP_24H ))</div><div>Expiring Resources</div></div>

    <h3>Action Summary</h3>
    <p>• Actionable for Cleanup: <strong>${ACTIONABLE_COUNT}</strong><br>
       • Deleted in Run: <strong>${DEL_COUNT}</strong> (Real), <strong>${SIM_COUNT}</strong> (Dry-run simulated)</p>
  </div>
  <div class='footer'>InfraReaper Automated Cloud Resource Lifecycle & Cost Manager</div>
</div></body></html>"

# ------------------------------------------------------------
# Dispatch Notification via SendGrid
# ------------------------------------------------------------
if [[ -z "${SENDGRID_API_KEY}" ]]; then
    log_info "SENDGRID_API_KEY is not configured. Email notification skipped (Dry-Run Notification)."
    log_info "Notification Subject would be: ${SUBJECT}"
    log_info "Configured recipient: ${NOTIFICATION_TO_EMAIL}"
    exit 0
fi

log_info "Dispatching notification email to ${NOTIFICATION_TO_EMAIL} (Sender: ${NOTIFICATION_FROM_EMAIL})..."

PAYLOAD=$(jq -n \
    --arg to "${NOTIFICATION_TO_EMAIL}" \
    --arg from "${NOTIFICATION_FROM_EMAIL}" \
    --arg subject "${SUBJECT}" \
    --arg html "${HTML_BODY}" \
    '{
        personalizations: [{ to: [{ email: $to }] }],
        from: { email: $from },
        subject: $subject,
        content: [{ type: "text/html", value: $html }]
    }')

RESPONSE_BODY=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    -X POST "https://api.sendgrid.com/v3/mail/send" \
    -H "Authorization: Bearer ${SENDGRID_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" || echo -e "\nHTTP_STATUS:FAILED")

HTTP_STATUS=$(echo "${RESPONSE_BODY}" | grep "^HTTP_STATUS:" | cut -d':' -f2)
ERROR_MSG=$(echo "${RESPONSE_BODY}" | grep -v "^HTTP_STATUS:")

if [[ "${HTTP_STATUS}" == "202" || "${HTTP_STATUS}" == "200" ]]; then
    log_success "Email notification successfully dispatched via SendGrid (HTTP ${HTTP_STATUS}) to ${NOTIFICATION_TO_EMAIL}."
else
    log_warn "Failed to dispatch email via SendGrid (HTTP Status: ${HTTP_STATUS})."
    if [[ -n "${ERROR_MSG}" ]]; then
        log_warn "SendGrid API Response: ${ERROR_MSG}"
    fi
fi

exit 0
