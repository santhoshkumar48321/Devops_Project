# ============================================================
# Module: policy — Variables
# ============================================================

variable "resource_group_id" {
  type        = string
  description = "Resource Group ID where the tagging policy will be assigned."
}

variable "policy_effect" {
  type        = string
  default     = "Audit"
  description = "Enforcement effect of the tagging policy: 'Audit' (flags non-compliance) or 'Deny' (blocks untagged creations)."
  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.policy_effect)
    error_message = "The policy_effect must be one of: 'Audit', 'Deny', or 'Disabled'."
  }
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target deployment environment."
}
