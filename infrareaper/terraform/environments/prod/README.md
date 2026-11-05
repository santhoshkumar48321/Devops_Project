# Production Terraform Environment (prod)

This directory defines the production deployment target for InfraReaper's cloud infrastructure on Microsoft Azure.

## 📌 Architecture & Design Principles

Unlike the `dev` sandbox environment, `prod` enforces enterprise-grade high availability, geo-redundancy, and enhanced governance:
- **AKS Production Cluster**: Multi-zone node pools with automatic autoscaling enabled (`Standard_D4s_v5` minimum).
- **Azure Container Registry**: Premium SKU with Geo-Replication and zone redundancy.
- **Key Vault**: Soft-delete enabled with 90-day retention and purge protection.
- **Remote State**: Separate dedicated Storage Account within `infrareaper-prod-state-rg` with container-level immutability policies.

## 🚀 Provisioning Workflow

```bash
# Initialize Terraform pointing to the production remote backend
terraform init \
  -backend-config="resource_group_name=infrareaper-prod-state-rg" \
  -backend-config="storage_account_name=infrareaperprodsa" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=prod.terraform.tfstate"

# Generate and review execution plan
terraform plan -var-file="terraform.tfvars" -out="prod.tfplan"

# Apply approved infrastructure changes
terraform apply "prod.tfplan"
```

## 🔒 Security Gate
All production infrastructure rollouts require approval via the Azure DevOps multi-stage pipeline release gate.
