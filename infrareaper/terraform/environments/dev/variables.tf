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

variable "alert_emails" {
  description = "Email addresses for budget notifications."
  type        = list(string)
  default     = ["santhoshkumar48321@gmail.com"]
}

