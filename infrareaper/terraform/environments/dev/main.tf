# ============================================================
# Environment: dev — Main Composition
# ============================================================
# Assembles all InfraReaper infrastructure modules for dev:
# Core RG + Networking + ACR + Key Vault + AKS + Budget + Test RG
# + Azure Tag Policy Shift-Left Guardrail
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
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}

data "azurerm_subscription" "current" {}

# ──────────────────────────────────────────────
# 1. Core Resource Group
# ──────────────────────────────────────────────
resource "azurerm_resource_group" "core_rg" {
  name     = var.core_resource_group_name
  location = var.location

  tags = {
    Project     = "InfraReaper"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ──────────────────────────────────────────────
# 2. Networking Module
# ──────────────────────────────────────────────
module "networking" {
  source              = "../../modules/networking"
  resource_group_name = azurerm_resource_group.core_rg.name
  location            = azurerm_resource_group.core_rg.location
  environment         = var.environment
}

# ──────────────────────────────────────────────
# 3. Azure Container Registry (ACR)
# ──────────────────────────────────────────────
module "acr" {
  source              = "../../modules/acr"
  resource_group_name = azurerm_resource_group.core_rg.name
  location            = azurerm_resource_group.core_rg.location
  environment         = var.environment
  sku                 = "Basic"
  admin_enabled       = true
}

# ──────────────────────────────────────────────
# 4. Azure Key Vault
# ──────────────────────────────────────────────
module "keyvault" {
  source              = "../../modules/keyvault"
  resource_group_name = azurerm_resource_group.core_rg.name
  location            = azurerm_resource_group.core_rg.location
  environment         = var.environment
}

# ──────────────────────────────────────────────
# 5. AKS Kubernetes Cluster
# ──────────────────────────────────────────────
module "aks" {
  source              = "../../modules/aks"
  resource_group_name = azurerm_resource_group.core_rg.name
  location            = azurerm_resource_group.core_rg.location
  environment         = var.environment
  system_subnet_id    = module.networking.subnet_id
  acr_id              = module.acr.acr_id
  vm_size             = "Standard_B2s"
  node_count          = 1
}

# ──────────────────────────────────────────────
# 6. Test Sandbox Resources (Scanner Targets)
# ──────────────────────────────────────────────
module "test_resources" {
  source              = "../../modules/test-resources"
  resource_group_name = var.test_resource_group_name
  location            = var.location
  enable_test_vms     = var.enable_test_vms
}

# ──────────────────────────────────────────────
# 7. Identity & RBAC (Scanner & Cleanup SPs)
# ──────────────────────────────────────────────
module "identity" {
  source                 = "../../modules/identity"
  subscription_id        = data.azurerm_subscription.current.subscription_id
  test_resource_group_id = module.test_resources.resource_group_id
  key_vault_id           = module.keyvault.key_vault_id
  environment            = var.environment
}

# ──────────────────────────────────────────────
# 8. Budget Alerts (Strict Spend Safeguard)
# ──────────────────────────────────────────────
module "budget" {
  source              = "../../modules/budget"
  enabled             = var.enable_budget
  resource_group_id   = azurerm_resource_group.core_rg.id
  budget_amount       = var.budget_amount
  notification_emails = var.alert_emails
}

# ──────────────────────────────────────────────
# 9. Monitoring Infrastructure (Log Analytics)
# ──────────────────────────────────────────────
module "monitoring_infra" {
  source              = "../../modules/monitoring-infra"
  resource_group_name = azurerm_resource_group.core_rg.name
  location            = azurerm_resource_group.core_rg.location
  environment         = var.environment
}

# ──────────────────────────────────────────────
# 10. Tag Governance Policy (Shift-Left Guardrail)
# ──────────────────────────────────────────────
module "tag_policy" {
  source            = "../../modules/policy"
  resource_group_id = module.test_resources.resource_group_id
  policy_effect     = var.tag_policy_effect
  environment       = var.environment
}
