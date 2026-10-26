# ============================================================
# Module: keyvault — Main
# ============================================================
# Provisions Azure Key Vault to securely store Service Principal
# credentials, tokens, and SendGrid API keys without exposing them.
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

data "azurerm_client_config" "current" {}

resource "random_string" "kv_suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_key_vault" "kv" {
  name                       = "${lower(var.key_vault_prefix)}-${random_string.kv_suffix.result}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.sku_name
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Access Policy for Terraform Deployer
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]
  }

  tags = merge(
    {
      Project     = "InfraReaper"
      Component   = "Key-Vault"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}
