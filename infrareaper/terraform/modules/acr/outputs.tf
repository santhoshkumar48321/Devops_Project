# ============================================================
# Module: acr — Outputs
# ============================================================

output "acr_id" {
  description = "The Resource ID of the Container Registry."
  value       = azurerm_container_registry.acr.id
}

output "acr_name" {
  description = "The name of the Container Registry."
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "The URL used to log in and push to the container registry."
  value       = azurerm_container_registry.acr.login_server
}

output "admin_username" {
  description = "The Admin Username for the ACR."
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "admin_password" {
  description = "The Admin Password for the ACR."
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}

