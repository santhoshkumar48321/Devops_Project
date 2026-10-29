# ============================================================
# Module: policy — Outputs
# ============================================================

output "policy_definition_id" {
  description = "The ID of the custom policy definition."
  value       = azurerm_policy_definition.require_mandatory_tags.id
}

output "policy_assignment_id" {
  description = "The ID of the policy assignment."
  value       = azurerm_resource_group_policy_assignment.tag_governance.id
}

