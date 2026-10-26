# ============================================================
# Module: budget — Main
# ============================================================
# Provisions automated Azure budget alerts to keep project spend
# strictly under $80, alerting at $10, $25, $50, $75 thresholds.
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0, < 5.0.0"
    }
  }
}

resource "azurerm_consumption_budget_resource_group" "budget" {
  name              = var.budget_name
  resource_group_id = var.resource_group_id
  amount            = var.budget_amount
  time_grain        = var.time_grain

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  # Alert 1: $10 threshold (~12.5% of $80)
  notification {
    operator       = "GreaterThan"
    threshold      = 12.5
    threshold_type = "Actual"
    contact_emails = var.notification_emails
  }

  # Alert 2: $25 threshold (~31.25% of $80)
  notification {
    operator       = "GreaterThan"
    threshold      = 31.25
    threshold_type = "Actual"
    contact_emails = var.notification_emails
  }

  # Alert 3: $50 threshold (62.5% of $80)
  notification {
    operator       = "GreaterThan"
    threshold      = 62.5
    threshold_type = "Actual"
    contact_emails = var.notification_emails
  }

  # Alert 4: $75 threshold (~93.75% of $80)
  notification {
    operator       = "GreaterThan"
    threshold      = 93.75
    threshold_type = "Actual"
    contact_emails = var.notification_emails
  }

  # Alert 5: Forecasted to exceed 100% ($80)
  notification {
    operator       = "GreaterThan"
    threshold      = 100.0
    threshold_type = "Forecasted"
    contact_emails = var.notification_emails
  }

  lifecycle {
    ignore_changes = [
      time_period[0].start_date
    ]
  }
}
