# ============================================================
# Module: budget — Variables
# ============================================================

variable "enabled" {
  description = "Enable or disable consumption budget resource (Azure Student accounts do not support API-managed budgets)."
  type        = bool
  default     = false
}

variable "resource_group_id" {
  description = "The Resource ID of the resource group to apply the budget to."
  type        = string
}

variable "budget_name" {
  description = "Name of the consumption budget."
  type        = string
  default     = "infrareaper-cost-budget"
}

variable "budget_amount" {
  description = "Total monthly budget amount in USD (Project limit: $80)."
  type        = number
  default     = 80
}

variable "notification_emails" {
  description = "Email addresses to alert when budget thresholds are hit."
  type        = list(string)
  default     = ["santhoshkumar48321@gmail.com"]
}

variable "time_grain" {
  description = "The time grain for the budget (Monthly, Quarterly, Annually)."
  type        = string
  default     = "Monthly"
}

