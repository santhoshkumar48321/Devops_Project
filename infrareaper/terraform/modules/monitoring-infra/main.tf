# ============================================================
# Module: monitoring-infra — Main
# ============================================================
# Provisions Log Analytics Workspace for cloud diagnostics and audits.
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0, < 5.0.0"
    }
  }
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days

  tags = merge(
    {
      Project     = "InfraReaper"
      Component   = "Monitoring-LAW"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

