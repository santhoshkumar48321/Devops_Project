# ============================================================
# Module: identity — Variables
# ============================================================

variable "subscription_id" {
  description = "The Azure Subscription ID where the scanner will read resources."
  type        = string
}

variable "test_resource_group_id" {
  description = "The Resource ID of infrareaper-test-resources RG (cleanup SP scope)."
  type        = string
}

variable "key_vault_id" {
  description = "Resource ID of the Key Vault where SP credentials are stored."
  type        = string
}

variable "environment" {
  description = "Environment identifier (dev, prod)."
  type        = string
  default     = "dev"
}

