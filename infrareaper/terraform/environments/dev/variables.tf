# ============================================================
# Environment: dev — Variables
# ============================================================

variable "location" {
  description = "Primary Azure region for dev infrastructure."
  type        = string
  default     = "centralindia"
}

variable "core_resource_group_name" {
  description = "Resource Group holding core InfraReaper infrastructure."
  type        = string
  default     = "infrareaper-core-rg"
}

variable "test_resource_group_name" {
  description = "Resource Group holding test target resources for the scanner."
  type        = string
  default     = "infrareaper-test-resources"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "enable_test_vms" {
  description = "Deploy test VMs in the test sandbox."
  type        = bool
  default     = true
}

variable "budget_amount" {
  description = "Monthly budget limit in USD."
  type        = number
  default     = 80
}

variable "enable_budget" {
  description = "Enable Azure Consumption Budget (disabled by default for Azure Student subscriptions)."
  type        = bool
  default     = false
}

variable "alert_emails" {
  description = "Email addresses for budget notifications."
  type        = list(string)
  default     = ["santhoshkumar48321@gmail.com"]
}

variable "tag_policy_effect" {
  description = "Effect of Azure Policy for mandatory tags (Audit, Deny, Disabled)."
  type        = string
  default     = "Audit"
}
