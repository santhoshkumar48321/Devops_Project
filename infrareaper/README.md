# InfraReaper 🪦

**Cloud Resource Lifecycle & Cost Manager**

> *Automated scanning, policy enforcement, and cleanup of cloud resources — because engineers create resources, then forget to delete them.*

---

## The Problem

Cloud waste averages **25–35% of total cloud spend**. Engineers spin up VMs, storage accounts, and databases for testing, then forget to delete them. Tags are missing or inconsistent. Nobody tracks ownership or expiry. The monthly bill grows silently.

## The Solution

InfraReaper automatically:
1. **Scans** Azure resources on a schedule (K8s CronJob, every 30 min)
2. **Evaluates** tag policies — are required tags present? are resources expired?
3. **Notifies** resource owners via email (SendGrid) about violations and upcoming expirations
4. **Cleans up** expired resources safely — with protected resource lists, dry-run mode, and audit logging
5. **Reports** via Grafana dashboards — resource inventory, cost attribution, compliance scores, SLO tracking

## Architecture

```
Lab Server (Ubuntu 24.04)          Azure Cloud
┌─────────────────────┐    ┌───────────────────────────────────┐
│ Azure DevOps Agent  │───►│ AKS Cluster                       │
│ Ansible Control     │    │  ├── Scanner CronJob (Bash + az)  │
└─────────────────────┘    │  ├── Prometheus + Pushgateway     │
                           │  ├── Grafana (SSO via Entra ID)   │
                           │  ├── Loki + Promtail              │
                           │  └── AlertManager → SendGrid      │
                           │                                   │
                           │ ACR │ Key Vault │ Entra ID        │
                           └───────────────────────────────────┘
```

## Tech Stack

| Layer | Technology |
|---|---|
| Infrastructure as Code | Terraform |
| Configuration Management | Ansible |
| Container Orchestration | AKS (Kubernetes) |
| CI/CD | Azure DevOps Pipelines |
| Scanner Application | Bash + `az cli` + `jq` |
| Container Registry | Azure Container Registry (ACR) |
| Secrets Management | Azure Key Vault |
| Identity & Access | Entra ID (Service Principals, RBAC, SSO) |
| Monitoring | Prometheus + Grafana |
| Logging | Loki + Promtail |
| Notifications | SendGrid (email) |
| Security Scanning | Trivy (IaC + container images) |

## Project Structure

```
infrareaper/
├── docs/              # Architecture, requirements, runbook, security model
├── terraform/         # Azure infrastructure (modules + environments)
├── ansible/           # Lab server configuration (roles + playbooks)
├── scripts/           # Scanner application (Bash)
├── docker/            # Dockerfile + .dockerignore
├── kubernetes/        # K8s manifests (Kustomize base + overlays)
├── pipelines/         # Azure DevOps CI/CD pipeline YAML
├── policies/          # Tag policies, protected resources, lifecycle rules
└── tests/             # Validation scripts (shellcheck, terraform, kubeval)
```

## Quick Start

```bash
# Lint everything
make lint

# Build scanner image
make build IMAGE_TAG=dev

# Security scan
make scan

# Deploy to AKS (dev)
make deploy
```

## Documentation

- [Requirements](docs/requirements.md)
- [Architecture](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Security Model](docs/security-model.md)
- [Monitoring](docs/monitoring.md)
- [Runbook](docs/runbook.md)
- [Cost Analysis](docs/cost-analysis.md)

## Status

🚧 **In Development** — Building phase by phase.

## License

MIT
