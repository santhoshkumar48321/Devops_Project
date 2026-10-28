#!/usr/bin/env bash
# ============================================================
# InfraReaper Policy Evaluator (evaluate-policies.sh)
# ============================================================
# Evaluates resource tags against governance policies defined in
# policies/tag-policies.yaml. Produces a compliance score and
# itemized violation audit.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

INVENTORY_FILE="${OUTPUT_DIR}/inventory.json"
COMPLIANCE_FILE="${OUTPUT_DIR}/compliance-report.json"
POLICY_FILE="${POLICY_FILE:-${SCRIPT_DIR}/../policies/tag-policies.yaml}"

log_info "=== Starting Policy Evaluation ==="

if [[ ! -f "${INVENTORY_FILE}" ]]; then
    log_error "Inventory file not found: ${INVENTORY_FILE}"
    log_error "Please run scan.sh first."
    exit 1
fi

EVALUATED_AT="$(_timestamp)"
log_info "Evaluating inventory against tag policies..."

# ------------------------------------------------------------
# Perform Evaluation using jq
# ------------------------------------------------------------
jq \
    --arg evaluated_at "${EVALUATED_AT}" \
    '
    def get_tag(tags; key):
        (tags | to_entries[] | select(.key | ascii_downcase == (key | ascii_downcase)) | .value) // null;

    def evaluate_resource:
        . as $res |
        ($res.tags // {}) as $tags |

        # Tag 1: owner
        (get_tag($tags; "owner")) as $owner_val |
        (
            if $owner_val == null or $owner_val == "" then
                [{tag: "owner", severity: "CRITICAL", message: "Missing required tag: owner"}]
            elif ($owner_val | test("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$|^[a-zA-Z0-9_-]+$") | not) then
                [{tag: "owner", severity: "CRITICAL", message: ("Invalid owner tag value: " + $owner_val)}]
            else
                []
            end
        ) as $owner_violations |

        # Tag 2: environment
        (get_tag($tags; "environment")) as $env_val |
        (
            if $env_val == null or $env_val == "" then
                [{tag: "environment", severity: "WARNING", message: "Missing required tag: environment"}]
            elif (["dev", "staging", "prod", "test"] | index($env_val | ascii_downcase)) == null then
                [{tag: "environment", severity: "INFO", message: ("Environment \"" + $env_val + "\" is invalid. Allowed: dev, staging, prod, test")}]
            else
                []
            end
        ) as $env_violations |

        # Tag 3: expiry-date (supports expiry-date, expiryDate, expire-date, expireDate, expiration-date, etc.)
        (get_tag($tags; "expiry-date") // get_tag($tags; "expiry_date") // get_tag($tags; "expirydate") // get_tag($tags; "expire-date") // get_tag($tags; "expire_date") // get_tag($tags; "expiredate") // get_tag($tags; "expiration-date") // get_tag($tags; "expirationdate") // get_tag($tags; "expires")) as $exp_val |
        (
            if $exp_val == null or $exp_val == "" then
                [{tag: "expiry-date", severity: "WARNING", message: "Missing required tag: expiry-date"}]
            elif ($exp_val | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not) then
                [{tag: "expiry-date", severity: "WARNING", message: ("Invalid expiry-date format: \"" + $exp_val + "\". Expected YYYY-MM-DD")}]
            else
                []
            end
        ) as $exp_violations |

        ($owner_violations + $env_violations + $exp_violations) as $all_violations |

        $res + {
            owner: $owner_val,
            environment: $env_val,
            expiry_date: $exp_val,
            is_compliant: ($all_violations | length == 0),
            violations: $all_violations
        };

    .resources | map(evaluate_resource) as $evaluated |

    ($evaluated | length) as $total |
    ([$evaluated[] | select(.is_compliant == true)] | length) as $compliant |
    ($total - $compliant) as $non_compliant |
    (if $total > 0 then (($compliant / $total) * 10000 | round) / 100 else 100.0 end) as $score |

    ([$evaluated[].violations[] | select(.severity == "CRITICAL")] | length) as $critical_count |
    ([$evaluated[].violations[] | select(.severity == "WARNING")] | length) as $warning_count |
    ([$evaluated[].violations[] | select(.severity == "INFO")] | length) as $info_count |

    {
        summary: {
            evaluated_at: $evaluated_at,
            total_resources: $total,
            compliant_resources: $compliant,
            non_compliant_resources: $non_compliant,
            compliance_score: $score,
            min_threshold_percent: 85,
            meets_threshold: ($score >= 85),
            violations_by_severity: {
                CRITICAL: $critical_count,
                WARNING: $warning_count,
                INFO: $info_count
            }
        },
        resources: $evaluated
    }
    ' "${INVENTORY_FILE}" > "${COMPLIANCE_FILE}"

TOTAL_RES=$(jq '.summary.total_resources' "${COMPLIANCE_FILE}")
COMPLIANT_RES=$(jq '.summary.compliant_resources' "${COMPLIANCE_FILE}")
SCORE=$(jq '.summary.compliance_score' "${COMPLIANCE_FILE}")
CRIT_VIOL=$(jq '.summary.violations_by_severity.CRITICAL' "${COMPLIANCE_FILE}")
WARN_VIOL=$(jq '.summary.violations_by_severity.WARNING' "${COMPLIANCE_FILE}")

log_success "=== Policy Evaluation Complete ==="
log_info "Total Resources: ${TOTAL_RES}"
log_info "Compliant Resources: ${COMPLIANT_RES} / ${TOTAL_RES}"
log_info "Compliance Score: ${SCORE}%"
log_info "Violations: ${CRIT_VIOL} Critical, ${WARN_VIOL} Warning"
log_info "Report saved to: ${COMPLIANCE_FILE}"
