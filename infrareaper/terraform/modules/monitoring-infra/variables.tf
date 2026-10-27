# ============================================================
# Module: monitoring-infra — Variables
# ============================================================

variable "resource_group_name" {
  description = "Resource group for the monitoring infrastructure."
  type        = string
}

variable "location" {
  description = "Azure region for the Log Analytics workspace."
  type        = string
}

variable "environment" {
  description = "Environment identifier (dev, prod)."
  type        = string
  default     = "dev"
}

variable "workspace_name" {
  description = "Name of the Log Analytics Workspace."
  type        = string
  default     = "infrareaper-law"
}

variable "retention_in_days" {
  description = "Workspace data retention in days (30 days is free tier standard)."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to the Log Analytics Workspace."
  type        = map(string)
  default     = {}
}

