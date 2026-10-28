#!/usr/bin/env bash
# ============================================================
# InfraReaper Shared Utility Library (common.sh)
# ============================================================
# Provides shared logging, error handling, dependency checking,
# and authentication routines for all InfraReaper scripts.
# ============================================================

set -euo pipefail

# Text colors for terminal output
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_PURPLE='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_RESET='\033[0m'

# Default runtime configuration
export OUTPUT_DIR="${OUTPUT_DIR:-/tmp/infrareaper}"
export LOG_LEVEL="${LOG_LEVEL:-INFO}" # DEBUG, INFO, WARN, ERROR
export TARGET_RESOURCE_GROUPS="${TARGET_RESOURCE_GROUPS:-infrareaper-test-resources}"
export DRY_RUN="${DRY_RUN:-true}"
export ENVIRONMENT="${ENVIRONMENT:-dev}"

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

# ------------------------------------------------------------
# Logging Functions
# ------------------------------------------------------------
_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log_info() {
    echo -e "${COLOR_BLUE}[$(_timestamp)] [INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[$(_timestamp)] [SUCCESS]${COLOR_RESET} $*"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[$(_timestamp)] [WARN]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[$(_timestamp)] [ERROR]${COLOR_RESET} $*" >&2
}

log_debug() {
    if [[ "${LOG_LEVEL}" == "DEBUG" ]]; then
        echo -e "${COLOR_PURPLE}[$(_timestamp)] [DEBUG]${COLOR_RESET} $*"
    fi
}

# ------------------------------------------------------------
# Dependency Checking
# ------------------------------------------------------------
check_dependencies() {
    local missing_deps=()
    local required_cmds=("az" "jq" "curl")

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_deps+=("${cmd}")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install them before running InfraReaper."
        return 1
    fi

    log_debug "All required dependencies present: ${required_cmds[*]}"
    return 0
}

# ------------------------------------------------------------
# Azure Authentication
# ------------------------------------------------------------
# Authenticates using Service Principal credentials if provided,
# otherwise verifies existing Azure CLI session (managed identity/ambient).
azure_login() {
    local client_id="${1:-${AZURE_CLIENT_ID:-}}"
    local client_secret="${2:-${AZURE_CLIENT_SECRET:-}}"
    local tenant_id="${3:-${AZURE_TENANT_ID:-}}"

    if [[ -n "${client_id}" && -n "${client_secret}" && -n "${tenant_id}" ]]; then
        log_info "Authenticating with Azure via Service Principal (${client_id:0:8}...)..."
        az login --service-principal \
            --username "${client_id}" \
            --password "${client_secret}" \
            --tenant "${tenant_id}" \
            --output none
        log_success "Azure authentication successful via Service Principal."
    else
        log_info "Verifying ambient/managed identity Azure authentication..."
        if ! az account show --output none 2>/dev/null; then
            log_error "Not authenticated to Azure and no Service Principal credentials supplied."
            log_error "Set AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID or run 'az login'."
            return 1
        fi
        local current_sub
        current_sub=$(az account show --query "id" -o tsv)
        log_success "Using active Azure subscription: ${current_sub}"
    fi
    return 0
}

