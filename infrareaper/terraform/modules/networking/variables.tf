# ============================================================
# Module: networking — Variables
# ============================================================

variable "resource_group_name" {
  description = "Resource group where the network infrastructure resides."
  type        = string
}

variable "location" {
  description = "Azure region for the virtual network."
  type        = string
}

variable "environment" {
  description = "Environment identifier (e.g. dev, prod)."
  type        = string
  default     = "dev"
}

variable "vnet_name" {
  description = "Name of the Virtual Network."
  type        = string
  default     = "infrareaper-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "system_subnet_name" {
  description = "Name of the subnet hosting the AKS cluster nodes."
  type        = string
  default     = "aks-system-subnet"
}

variable "system_subnet_prefixes" {
  description = "Address prefix for the AKS system subnet."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "tags" {
  description = "Tags applied to all networking resources."
  type        = map(string)
  default     = {}
}
