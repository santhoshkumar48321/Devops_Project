# ============================================================
# Module: identity — Outputs
# ============================================================

output "scanner_client_id" {
  description = "Client ID for the scanner Service Principal."
  value       = azuread_application.scanner.client_id
}

output "cleanup_client_id" {
  description = "Client ID for the cleanup Service Principal."
  value       = azuread_application.cleanup.client_id
}
