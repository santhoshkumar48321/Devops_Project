# ============================================================
# Environment: dev — Outputs
# ============================================================

output "core_resource_group_name" {
  description = "Name of the Core Resource Group."
  value       = azurerm_resource_group.core_rg.name
}

output "test_resource_group_name" {
  description = "Name of the Test Target Resource Group."
  value       = module.test_resources.resource_group_name
}

output "aks_cluster_name" {
  description = "Name of the AKS Cluster."
  value       = module.aks.cluster_name
}

output "aks_connect_command" {
  description = "Azure CLI command to configure kubectl credentials."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.core_rg.name} --name ${module.aks.cluster_name} --overwrite-existing"
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = module.acr.acr_name
}

output "acr_login_server" {
  description = "Login server for the Azure Container Registry."
  value       = module.acr.acr_login_server
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault."
  value       = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault."
  value       = module.keyvault.key_vault_uri
}

output "scanner_client_id" {
  description = "Client ID for Scanner Service Principal."
  value       = module.identity.scanner_client_id
}

output "cleanup_client_id" {
  description = "Client ID for Cleanup Service Principal."
  value       = module.identity.cleanup_client_id
}

