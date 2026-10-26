# ============================================================
# Module: identity — Main
# ============================================================
# Creates the Service Principals and RBAC role assignments:
# 1. Scanner SP: Reader at Subscription scope (least privilege read)
# 2. Cleanup SP: Contributor ONLY at Test Resource Group (safety boundary)
# Stores generated secrets directly into Azure Key Vault.
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0, < 5.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.40.0"
    }
  }
}

data "azurerm_client_config" "current" {}

# ──────────────────────────────────────────────
# 1. Scanner Service Principal (Reader @ Subscription)
# ──────────────────────────────────────────────
resource "azuread_application" "scanner" {
  display_name = "sp-infrareaper-scanner-${var.environment}"
}

resource "azuread_service_principal" "scanner" {
  client_id = azuread_application.scanner.client_id
}

resource "azuread_service_principal_password" "scanner" {
  service_principal_id = azuread_service_principal.scanner.id
}

resource "azurerm_role_assignment" "scanner_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.scanner.object_id
}

# ──────────────────────────────────────────────
# 2. Cleanup Service Principal (Contributor @ Test RG ONLY)
# ──────────────────────────────────────────────
resource "azuread_application" "cleanup" {
  display_name = "sp-infrareaper-cleanup-${var.environment}"
}

resource "azuread_service_principal" "cleanup" {
  client_id = azuread_application.cleanup.client_id
}

resource "azuread_service_principal_password" "cleanup" {
  service_principal_id = azuread_service_principal.cleanup.id
}

resource "azurerm_role_assignment" "cleanup_contributor" {
  scope                = var.test_resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.cleanup.object_id
}

# ──────────────────────────────────────────────
# 3. Store Secrets in Key Vault
# ──────────────────────────────────────────────
resource "azurerm_key_vault_secret" "scanner_client_id" {
  name         = "AZURE-CLIENT-ID"
  value        = azuread_application.scanner.client_id
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "scanner_client_secret" {
  name         = "AZURE-CLIENT-SECRET"
  value        = azuread_service_principal_password.scanner.value
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "tenant_id" {
  name         = "AZURE-TENANT-ID"
  value        = data.azurerm_client_config.current.tenant_id
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "cleanup_client_id" {
  name         = "CLEANUP-CLIENT-ID"
  value        = azuread_application.cleanup.client_id
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "cleanup_client_secret" {
  name         = "CLEANUP-CLIENT-SECRET"
  value        = azuread_service_principal_password.cleanup.value
  key_vault_id = var.key_vault_id
}
