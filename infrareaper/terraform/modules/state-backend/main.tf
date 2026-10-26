# ============================================================
# Module: state-backend — Main
# ============================================================
# Creates the Azure Storage Account and Blob Container to host
# Terraform remote state with state locking and blob versioning.
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

# ──────────────────────────────────────────────
# 1. Dedicated State Resource Group
# ──────────────────────────────────────────────
resource "azurerm_resource_group" "state_rg" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(
    {
      Project     = "InfraReaper"
      Component   = "Terraform-State-Backend"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ──────────────────────────────────────────────
# 2. Random Suffix for Global Uniqueness
# ──────────────────────────────────────────────
# Azure Storage Account names must be globally unique across all of Azure,
# 3-24 characters, lowercase alphanumeric only.
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# ──────────────────────────────────────────────
# 3. Secure Storage Account
# ──────────────────────────────────────────────
resource "azurerm_storage_account" "state_sa" {
  name                     = "${var.storage_account_prefix}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.state_rg.name
  location                 = azurerm_resource_group.state_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Lowest cost replication (sufficient for lab)
  min_tls_version          = "TLS1_2"

  # Security best practices
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 14
    }
  }

  tags = merge(
    {
      Project     = "InfraReaper"
      Component   = "Terraform-State-Backend"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ──────────────────────────────────────────────
# 4. Blob Container for .tfstate files
# ──────────────────────────────────────────────
resource "azurerm_storage_container" "tfstate" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.state_sa.name
  container_access_type = "private"
}
