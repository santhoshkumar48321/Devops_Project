# Terraform IaC Test Suite

This directory contains testing specifications, static analysis guidelines, and compliance checks for InfraReaper's Terraform modules and environments.

## 🧪 Testing Scope

- **Terraform Format & Validate**: Enforces HCL syntax conventions and variable integrity (`terraform fmt -check`, `terraform validate`).
- **Trivy IaC Misconfiguration Scan**: Asserts 0 High / 0 Critical security violations across all 10 modules (ensures NSGs, TLS 1.2+, disk encryption, and private endpoints are enforced).
- **ARM Policy Gate Testing**: Asserts that `Deny` rules block non-compliant resource deployments.

## 🚀 Running Tests Locally

```bash
# 1. Format and validation check
terraform -chdir=infrareaper/terraform/environments/dev fmt -check
terraform -chdir=infrareaper/terraform/environments/dev validate

# 2. Run Trivy IaC security scan
trivy config infrareaper/terraform/
```
