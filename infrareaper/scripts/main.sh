#!/usr/bin/env bash
# ============================================================
# InfraReaper Master Orchestrator (main.sh)
# ============================================================
# Entrypoint for the InfraReaper scanning container and CronJob.
# Executes the complete lifecycle workflow sequentially:
# Scan -> Evaluate -> Expiry -> Cleanup -> Notify -> Push Metrics
# ============================================================

set -uo pipefail

START_TIME=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

SCAN_SUCCESS=1

finish_execution() {
    local exit_code=$?
    local end_time
    end_time=$(date +%s)
    local duration=$(( end_time - START_TIME ))

    if [[ ${exit_code} -ne 0 ]]; then
        SCAN_SUCCESS=0
        log_error "InfraReaper execution failed with exit code ${exit_code} after ${duration} seconds."
    else
        log_success "InfraReaper completed successfully in ${duration} seconds."
    fi

    # Ensure metrics are always pushed for SLO tracking (NFR-REL-01, FR-MET-03)
    export SCAN_DURATION="${duration}"
    export SCAN_SUCCESS="${SCAN_SUCCESS}"
    bash "${SCRIPT_DIR}/push-metrics.sh" || true

    log_info "=== InfraReaper Run Terminated ==="
    exit ${exit_code}
}

trap finish_execution EXIT

log_info "============================================================"
log_info "      InfraReaper Cloud Lifecycle & Governance Engine      "
log_info "============================================================"
log_info "Environment: ${ENVIRONMENT}"
log_info "Dry-Run:     ${DRY_RUN}"
log_info "Output Dir:  ${OUTPUT_DIR}"
log_info "------------------------------------------------------------"

# Step 1: Pre-flight Verification
log_info "Step 1/6: Running Pre-flight Checks..."
check_dependencies
azure_login

# Step 2: Inventory Scanning
log_info "Step 2/6: Executing Resource Inventory Scan..."
bash "${SCRIPT_DIR}/scan.sh"

# Step 3: Policy Compliance Evaluation
log_info "Step 3/6: Evaluating Governance Policies..."
bash "${SCRIPT_DIR}/evaluate-policies.sh"

# Step 4: Lifecycle & Expiry Calculation
log_info "Step 4/6: Calculating Expiry & Lifecycle States..."
bash "${SCRIPT_DIR}/check-expiry.sh"

# Step 5: Safe Automated Cleanup
log_info "Step 5/6: Executing Automated Cleanup Routine..."
bash "${SCRIPT_DIR}/cleanup.sh"

# Step 6: Notification Dispatch
log_info "Step 6/6: Dispatching Notifications..."
bash "${SCRIPT_DIR}/notify.sh"

log_success "All scanning and governance steps finished."

