#!/usr/bin/env bash
# ============================================================
# InfraReaper Notification Engine (notify.sh)
# ============================================================
# Dispatches consolidated compliance alerts, lifecycle expiry
# warnings, and cleanup audit digests via Slack Incoming Webhook
# and/or SendGrid v3 API. Enforces smart anti-fatigue filtering
# so notifications are only sent when action is needed.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

COMPLIANCE_FILE="${OUTPUT_DIR}/compliance-report.json"
LIFECYCLE_FILE="${OUTPUT_DIR}/lifecycle-report.json"
AUDIT_FILE="${OUTPUT_DIR}/cleanup-audit.json"

SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
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
CRIT_COUNT=$(jq '.summary.violations_by_severity.CRITICAL // 0' "${COMPLIANCE_FILE}")
WARN_COUNT=$(jq '.summary.violations_by_severity.WARNING // 0' "${COMPLIANCE_FILE}")

EXP_7D=$(jq '.summary.expiring_7d // 0' "${LIFECYCLE_FILE}")
EXP_72H=$(jq '.summary.expiring_72h // 0' "${LIFECYCLE_FILE}")
EXP_24H=$(jq '.summary.expiring_24h // 0' "${LIFECYCLE_FILE}")
EXP_GRACE=$(jq '.summary.expired_in_grace // 0' "${LIFECYCLE_FILE}")
ACTIONABLE_COUNT=$(jq '.summary.actionable_for_cleanup // 0' "${LIFECYCLE_FILE}")

DEL_COUNT=0
SIM_COUNT=0
if [[ -f "${AUDIT_FILE}" ]]; then
    DEL_COUNT=$(jq '.audit_metadata.deleted_count // 0' "${AUDIT_FILE}")
    SIM_COUNT=$(jq '.audit_metadata.dry_run_simulated_count // 0' "${AUDIT_FILE}")
fi

TOTAL_EXPIRING=$(( EXP_7D + EXP_72H + EXP_24H + EXP_GRACE ))

# ------------------------------------------------------------
# Smart Anti-Fatigue Filter (No Spam Rule)
# ------------------------------------------------------------
# Only notify if there are expiring assets, critical violations, or cleanup actions!
if [[ ${TOTAL_EXPIRING} -eq 0 && ${ACTIONABLE_COUNT} -eq 0 && ${DEL_COUNT} -eq 0 && ${CRIT_COUNT} -eq 0 ]]; then
    log_info "All resources compliant with 0 expiring assets and 0 cleanup actions."
    log_info "Notification skipped to avoid channel spam (Alert Fatigue Guard active)."
    exit 0
fi

SUBJECT="[InfraReaper Alert] Environment: ${ENVIRONMENT^^} | Compliance Score: ${SCORE}%"

# ------------------------------------------------------------
# 1. Dispatch Notification to Slack (if configured)
# ------------------------------------------------------------
if [[ -n "${SLACK_WEBHOOK_URL}" ]]; then
    log_info "Dispatching rich alert card to Slack..."

    # Extract itemized list of expiring resources (up to 10 items)
    EXPIRING_LIST=$(jq -r '
        [.resources[] | select(.lifecycle_state != "ACTIVE")] |
        if length == 0 then "None"
        else map("• `" + .name + "` (" + (.owner // "no-owner") + ") - *" + .lifecycle_state + "* (Expiry: `" + (.effective_expiry_date // "N/A") + "`)") | .[0:10] | join("\n") end
    ' "${LIFECYCLE_FILE}")

    # Extract itemized list of cleanup actions
    CLEANUP_LIST="None"
    if [[ -f "${AUDIT_FILE}" ]]; then
        CLEANUP_LIST=$(jq -r '
            [.actions[]? | select(.action_status == "DELETED" or .action_status == "DRY_RUN_DELETE_SIMULATED")] |
            if length == 0 then "None"
            else map("• `" + .resource_name + "` - *" + .action_status + "* (" + .resource_type + ")") | .[0:10] | join("\n") end
        ' "${AUDIT_FILE}")
    fi

    STATUS_EMOJI="⚠️"
    if [[ ${CRIT_COUNT} -gt 0 || ${ACTIONABLE_COUNT} -gt 0 || ${DEL_COUNT} -gt 0 ]]; then
        STATUS_EMOJI="🚨"
    fi

    SLACK_PAYLOAD=$(jq -n \
        --arg emoji "${STATUS_EMOJI}" \
        --arg env "${ENVIRONMENT^^}" \
        --arg score "${SCORE}%" \
        --arg compliant "${COMPLIANT_RES}/${TOTAL_RES}" \
        --arg expiring "${TOTAL_EXPIRING}" \
        --arg actionable "${ACTIONABLE_COUNT}" \
        --arg deleted "${DEL_COUNT} real / ${SIM_COUNT} dry-run" \
        --arg exp_list "${EXPIRING_LIST}" \
        --arg clean_list "${CLEANUP_LIST}" \
        --arg time "$(_timestamp)" \
        '{
            text: ($emoji + " [InfraReaper Alert] " + $env + " | Compliance: " + $score),
            blocks: [
                {
                    type: "header",
                    text: {
                        type: "plain_text",
                        text: ($emoji + " InfraReaper Cloud Governance Digest [" + $env + "]")
                    }
                },
                {
                    type: "section",
                    fields: [
                        { type: "mrkdwn", text: ("*Compliance Score:*\n`" + $score + "`") },
                        { type: "mrkdwn", text: ("*Compliant Assets:*\n`" + $compliant + "`") },
                        { type: "mrkdwn", text: ("*Expiring Assets:*\n`" + $expiring + "`") },
                        { type: "mrkdwn", text: ("*Purged Assets:*\n`" + $deleted + "`") }
                    ]
                },
                {
                    type: "section",
                    text: {
                        type: "mrkdwn",
                        text: ("*⏳ Expiring Resources:*\n" + $exp_list)
                    }
                },
                {
                    type: "section",
                    text: {
                        type: "mrkdwn",
                        text: ("*🧹 Cleanup Actions Executed:*\n" + $clean_list)
                    }
                },
                {
                    type: "context",
                    elements: [
                        { type: "mrkdwn", text: ("_InfraReaper Autonomous Janitor Engine • " + $time + "_") }
                    ]
                }
            ]
        }')

    SLACK_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${SLACK_WEBHOOK_URL}" \
        -H "Content-type: application/json" \
        --data "${SLACK_PAYLOAD}")

    if [[ "${SLACK_HTTP}" == "200" ]]; then
        log_success "Slack alert successfully dispatched (HTTP 200)."
    else
        log_warn "Failed to dispatch Slack alert (HTTP ${SLACK_HTTP})."
    fi
else
    log_info "SLACK_WEBHOOK_URL is not configured. Slack alert skipped."
fi

# ------------------------------------------------------------
# 2. Dispatch Notification via SendGrid (if configured)
# ------------------------------------------------------------
if [[ -z "${SENDGRID_API_KEY}" ]]; then
    log_info "SENDGRID_API_KEY is not configured. Email notification skipped."
    exit 0
fi

log_info "Dispatching notification email to ${NOTIFICATION_TO_EMAIL} (Sender: ${NOTIFICATION_FROM_EMAIL})..."

HTML_BODY="<html><head><style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #333; margin: 0; padding: 20px; background-color: #f7f9fc; }
.container { max-width: 650px; margin: 0 auto; background: #ffffff; border-radius: 8px; border: 1px solid #e1e4e8; overflow: hidden; }
.header { background: #0078d4; color: #ffffff; padding: 20px; text-align: center; }
.content { padding: 24px; }
.metric-box { display: inline-block; width: 45%; margin: 2%; padding: 12px; background: #f1f3f5; border-radius: 6px; text-align: center; vertical-align: top; }
.metric-val { font-size: 24px; font-weight: bold; color: #0078d4; }
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
    <div class='metric-box'><div class='metric-val'>${TOTAL_EXPIRING}</div><div>Expiring Resources</div></div>

    <h3>Action Summary</h3>
    <p>• Actionable for Cleanup: <strong>${ACTIONABLE_COUNT}</strong><br>
       • Deleted in Run: <strong>${DEL_COUNT}</strong> (Real), <strong>${SIM_COUNT}</strong> (Dry-run simulated)</p>
  </div>
  <div class='footer'>InfraReaper Automated Cloud Resource Lifecycle & Cost Manager</div>
</div></body></html>"

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
