#!/usr/bin/env bash
# ============================================================
# InfraReaper — Bootstrap Terraform Remote State Backend
# ============================================================
# This script solves the chicken-and-egg problem for Terraform:
# It creates the Azure Storage Account and Blob Container needed
# to store the remote Terraform state file before Terraform runs.
#
# Usage:
#   chmod +x scripts/bootstrap-state-backend.sh
#   ./scripts/bootstrap-state-backend.sh [LOCATION]
#
# Defaults:
#   LOCATION: centralindia
# ============================================================

set -euo pipefail

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
LOCATION="${1:-centralindia}"
RESOURCE_GROUP="infrareaper-state-rg"
CONTAINER_NAME="tfstate"

# Generate a unique 6-character random suffix for storage account name
UNIQUE_SUFFIX=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6 || true)
STORAGE_ACCOUNT_NAME="infrartf${UNIQUE_SUFFIX}"

echo "=================================================="
echo " InfraReaper — Bootstrapping Terraform State Backend"
echo "=================================================="
echo " Resource Group:   ${RESOURCE_GROUP}"
echo " Region:           ${LOCATION}"
echo " Storage Account:  ${STORAGE_ACCOUNT_NAME}"
echo " Container Name:   ${CONTAINER_NAME}"
echo "=================================================="

# Ensure user is logged in to Azure CLI
if ! az account show > /dev/null 2>&1; then
  echo "Error: Not logged in to Azure CLI. Please run 'az login' first."
  exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "→ Using Azure Subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})"

# 1. Create Resource Group
echo "→ Creating Resource Group '${RESOURCE_GROUP}'..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags Project=InfraReaper Component=Terraform-State-Backend ManagedBy=Bootstrap \
  --output none

# 2. Create Storage Account
echo "→ Creating Storage Account '${STORAGE_ACCOUNT_NAME}'..."
az storage account create \
  --name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags Project=InfraReaper Component=Terraform-State-Backend ManagedBy=Bootstrap \
  --output none

# 3. Enable Blob Versioning (protects state from accidental overwrites)
echo "→ Enabling Blob Versioning..."
az storage account blob-service-properties update \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --enable-versioning true \
  --output none

# 4. Create Blob Container for tfstate
echo "→ Creating Blob Container '${CONTAINER_NAME}'..."
az storage container create \
  --name "${CONTAINER_NAME}" \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --auth-mode login \
  --output none

echo "=================================================="
echo "✓ Backend Storage Successfully Created!"
echo "=================================================="
echo ""
echo "Update your 'terraform/environments/dev/backend.tf' with:"
echo ""
cat <<EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "${RESOURCE_GROUP}"
    storage_account_name = "${STORAGE_ACCOUNT_NAME}"
    container_name       = "${CONTAINER_NAME}"
    key                  = "infrareaper.dev.tfstate"
  }
}
EOF
echo ""
echo "=================================================="
