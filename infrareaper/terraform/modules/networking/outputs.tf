# ============================================================
# Module: networking — Outputs
# ============================================================

output "vnet_id" {
  description = "The Resource ID of the Virtual Network."
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "The name of the Virtual Network."
  value       = azurerm_virtual_network.vnet.name
}

output "subnet_id" {
  description = "The Resource ID of the AKS system subnet."
  value       = azurerm_subnet.system_subnet.id
}

output "subnet_name" {
  description = "The name of the AKS system subnet."
  value       = azurerm_subnet.system_subnet.name
}

output "nsg_id" {
  description = "The Resource ID of the Network Security Group."
  value       = azurerm_network_security_group.aks_nsg.id
}

output "nsg_name" {
  description = "The name of the Network Security Group."
  value       = azurerm_network_security_group.aks_nsg.name
}
