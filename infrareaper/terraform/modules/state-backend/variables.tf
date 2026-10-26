# ============================================================
# Module: state-backend — Variables
# ============================================================

variable "resource_group_name" {
  description = "Name of the resource group dedicated to Terraform remote state."
  type        = string
  default     = "infrareaper-state-rg"
}

variable "location" {
  description = "Azure region where the state backend storage account will reside."
  type        = string
  default     = "centralindia"
}

variable "environment" {
  description = "Environment identifier (e.g., dev, prod, shared)."
  type        = string
  default     = "shared"
}

variable "storage_account_prefix" {
  description = "Prefix for the storage account name (max 16 chars, alphanumeric lowercase only)."
  type        = string
  default     = "infrartfstate"

  validation {
    condition     = can(regex("^[a-z0-9]{3,16}$", var.storage_account_prefix))
    error_message = "Storage account prefix must be between 3 and 16 lowercase alphanumeric characters."
  }
}

variable "container_name" {
  description = "Name of the blob container holding the terraform .tfstate files."
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Tags applied to all backend state resources."
  type        = map(string)
  default     = {}
}
