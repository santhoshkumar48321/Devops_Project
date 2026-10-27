# ============================================================
# Module: state-backend — Outputs
# ============================================================

output "resource_group_name" {
  description = "The name of the resource group holding state storage."
  value       = azurerm_resource_group.state_rg.name
}

output "storage_account_name" {
  description = "The globally unique name of the state storage account."
  value       = azurerm_storage_account.state_sa.name
}

output "container_name" {
  description = "The name of the blob container holding the state files."
  value       = azurerm_storage_container.tfstate.name
}

output "storage_account_id" {
  description = "The Resource ID of the storage account."
  value       = azurerm_storage_account.state_sa.id
}

output "backend_config_snippet" {
  description = "Ready-to-use snippet for terraform backend block."
  value = <<-EOT
    terraform {
      backend "azurerm" {
        resource_group_name  = "${azurerm_resource_group.state_rg.name}"
        storage_account_name = "${azurerm_storage_account.state_sa.name}"
        container_name       = "${azurerm_storage_container.tfstate.name}"
        key                  = "infrareaper.dev.tfstate"
      }
    }
  EOT
}

