# ============================================================
# Module: monitoring-infra — Outputs
# ============================================================

output "workspace_id" {
  description = "The Resource ID of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.law.id
}

output "workspace_name" {
  description = "The name of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.law.name
}

output "primary_shared_key" {
  description = "Primary shared key for the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.law.primary_shared_key
  sensitive   = true
}
