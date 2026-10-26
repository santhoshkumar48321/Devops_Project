# ============================================================
# Environment: dev — Backend Configuration
# ============================================================
# Stores the dev environment state in Azure Blob Storage.
#
# Values are populated after running:
#   ./scripts/bootstrap-state-backend.sh
# ============================================================

terraform {
  backend "azurerm" {
    resource_group_name  = "infrareaper-state-rg"
    storage_account_name = "REPLACE_WITH_STORAGE_ACCOUNT_NAME"
    container_name       = "tfstate"
    key                  = "infrareaper.dev.tfstate"
  }
}
