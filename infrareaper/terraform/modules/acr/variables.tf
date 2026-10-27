# ============================================================
# Module: acr — Variables
# ============================================================

variable "resource_group_name" {
  description = "Resource group for the Azure Container Registry."
  type        = string
}

variable "location" {
  description = "Azure region for the ACR."
  type        = string
}

variable "environment" {
  description = "Environment identifier (dev, prod)."
  type        = string
  default     = "dev"
}

variable "acr_name_prefix" {
  description = "Prefix for the ACR name (alphanumeric only, 5-40 chars)."
  type        = string
  default     = "infrareaperacr"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,40}$", var.acr_name_prefix))
    error_message = "ACR name prefix must be alphanumeric."
  }
}

variable "sku" {
  description = "The SKU of the container registry (Basic, Standard, Premium)."
  type        = string
  default     = "Basic"
}

variable "admin_enabled" {
  description = "Enable admin user on the ACR."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the ACR."
  type        = map(string)
  default     = {}
}

