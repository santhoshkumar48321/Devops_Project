# ============================================================
# Module: test-resources — Outputs
# ============================================================

output "resource_group_name" {
  description = "Name of the test resource group."
  value       = azurerm_resource_group.test_rg.name
}

output "resource_group_id" {
  description = "Resource ID of the test resource group."
  value       = azurerm_resource_group.test_rg.id
}

output "tagged_vm_name" {
  description = "Name of the properly tagged test VM."
  value       = length(azurerm_linux_virtual_machine.tagged_vm) > 0 ? azurerm_linux_virtual_machine.tagged_vm[0].name : null
}

output "untagged_vm_name" {
  description = "Name of the untagged test VM (violation target)."
  value       = length(azurerm_linux_virtual_machine.untagged_vm) > 0 ? azurerm_linux_virtual_machine.untagged_vm[0].name : null
}

output "expired_storage_account_name" {
  description = "Name of the expired test storage account (cleanup target)."
  value       = azurerm_storage_account.expired_sa.name
}

output "orphan_public_ip_name" {
  description = "Name of the orphaned public IP."
  value       = azurerm_public_ip.orphan_ip.name
}

output "unattached_disk_name" {
  description = "Name of the unattached test managed disk."
  value       = azurerm_managed_disk.unattached_disk.name
}

