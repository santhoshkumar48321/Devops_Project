# ============================================================
# Module: budget — Outputs
# ============================================================

output "budget_id" {
  description = "The Resource ID of the consumption budget."
  value       = var.enabled && length(azurerm_consumption_budget_resource_group.budget) > 0 ? azurerm_consumption_budget_resource_group.budget[0].id : null
}

output "budget_name" {
  description = "The name of the consumption budget."
  value       = var.enabled && length(azurerm_consumption_budget_resource_group.budget) > 0 ? azurerm_consumption_budget_resource_group.budget[0].name : null
}

