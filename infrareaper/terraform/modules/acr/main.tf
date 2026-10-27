# ============================================================
# Module: acr — Main
# ============================================================
# Provisions an Azure Container Registry (ACR) to store
# scanner container images with a globally unique name.
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

resource "random_string" "acr_suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_container_registry" "acr" {
  name                = "${lower(var.acr_name_prefix)}${random_string.acr_suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  tags = merge(
    {
      Project     = "InfraReaper"
      Component   = "Container-Registry"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

