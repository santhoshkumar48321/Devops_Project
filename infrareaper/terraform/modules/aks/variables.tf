# ============================================================
# Module: aks — Variables
# ============================================================

variable "resource_group_name" {
  description = "Resource group for the AKS cluster."
  type        = string
}

variable "location" {
  description = "Azure region for the AKS cluster."
  type        = string
}

variable "environment" {
  description = "Environment identifier (dev, prod)."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "infrareaper-aks"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster control plane."
  type        = string
  default     = "infrareaper-k8s"
}

variable "vm_size" {
  description = "VM SKU for the default node pool (Standard_B2s = 2 vCPU, 4 GB RAM, lowest cost)."
  type        = string
  default     = "Standard_B2s"
}

variable "node_count" {
  description = "Number of nodes in the system node pool."
  type        = number
  default     = 1
}

variable "system_subnet_id" {
  description = "Resource ID of the subnet where AKS worker nodes run."
  type        = string
}

variable "acr_id" {
  description = "Resource ID of the Azure Container Registry to attach with AcrPull."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the AKS cluster."
  type        = map(string)
  default     = {}
}
