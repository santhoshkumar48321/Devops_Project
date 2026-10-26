# ============================================================
# Module: keyvault — Variables
# ============================================================

variable "resource_group_name" {
  description = "Resource group for the Key Vault."
  type        = string
}

variable "location" {
  description = "Azure region for the Key Vault."
  type        = string
}

variable "environment" {
  description = "Environment identifier (dev, prod)."
  type        = string
  default     = "dev"
}

variable "key_vault_prefix" {
  description = "Prefix for Key Vault name (max 18 chars, alphanumeric lowercase)."
  type        = string
  default     = "infrareaperkv"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,18}$", var.key_vault_prefix))
    error_message = "Key Vault prefix must be between 3 and 18 alphanumeric characters or hyphens."
  }
}

variable "sku_name" {
  description = "SKU tier for Key Vault (standard or premium)."
  type        = string
  default     = "standard"
}

variable "soft_delete_retention_days" {
  description = "Number of days that items should be retained once soft-deleted."
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Enable purge protection (disabled by default in dev/lab to allow easy destruction)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the Key Vault."
  type        = map(string)
  default     = {}
}
