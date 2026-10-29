# ============================================================
# Module: policy — Main
# ============================================================
# Provisions enterprise Azure Policy definitions and assignments
# to enforce mandatory tags (owner, environment, expiry-date)
# at the Azure Resource Manager (ARM) plane.
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

# ──────────────────────────────────────────────
# 1. Custom Policy Definition: Require Mandatory Tags
# ──────────────────────────────────────────────
resource "azurerm_policy_definition" "require_mandatory_tags" {
  name         = "infrareaper-require-tags-${var.environment}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "InfraReaper: Require mandatory tags on resources"
  description  = "Enforces or audits mandatory tags ('owner', 'environment', 'expiry-date') on Azure resources."

  metadata = jsonencode({
    category = "Governance"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect"
        description = "The execution effect of the policy (Audit, Deny, Disabled)"
      }
      allowedValues = [
        "Audit",
        "Deny",
        "Disabled"
      ]
      defaultValue = "Audit"
    }
  })

  policy_rule = jsonencode({
    if = {
      anyOf = [
        {
          field  = "tags['owner']"
          exists = "false"
        },
        {
          field  = "tags['environment']"
          exists = "false"
        },
        {
          field  = "tags['expiry-date']"
          exists = "false"
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

# ──────────────────────────────────────────────
# 2. Policy Assignment to Resource Group
# ──────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "tag_governance" {
  name                 = "ir-tag-gov-${var.environment}"
  resource_group_id    = var.resource_group_id
  policy_definition_id = azurerm_policy_definition.require_mandatory_tags.id
  display_name         = "InfraReaper Mandatory Tag Governance (${var.policy_effect})"
  description          = "Assigns tag governance policy enforcing owner, environment, and expiry-date."

  parameters = jsonencode({
    effect = {
      value = var.policy_effect
    }
  })
}
