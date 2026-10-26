# ============================================================
# Module: budget — Outputs
# ============================================================

output "budget_id" {
  description = "The Resource ID of the consumption budget."
  value       = azurerm_consumption_budget_resource_group.budget.id
}

output "budget_name" {
  description = "The name of the consumption budget."
  value       = azurerm_consumption_budget_resource_group.budget.name
}
