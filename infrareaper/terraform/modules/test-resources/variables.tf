# ============================================================
# Module: test-resources — Variables
# ============================================================

variable "resource_group_name" {
  description = "Resource group name for test target resources."
  type        = string
  default     = "infrareaper-test-resources"
}

variable "location" {
  description = "Azure region for test resources."
  type        = string
  default     = "centralindia"
}

variable "admin_username" {
  description = "Admin username for test VMs."
  type        = string
  default     = "reaperadmin"
}

variable "admin_password" {
  description = "Admin password for test VMs."
  type        = string
  default     = "InfraReaper!Test2026"
  sensitive   = true
}

variable "enable_test_vms" {
  description = "Toggle to deploy or destroy test VMs to optimize cost."
  type        = bool
  default     = true
}

