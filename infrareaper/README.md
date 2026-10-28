# InfraReaper 🪦

**Autonomous Cloud Resource Lifecycle, Governance & FinOps Engine on Microsoft Azure**

[![Azure](https://img.shields.io/badge/Azure-AKS%20%7C%20ACR%20%7C%20KeyVault-0078D4?logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform%20v1.12-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Config-Ansible%20Lab%20Automation-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes%20Kustomize-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-Azure%20DevOps%20Pipelines-0078D4?logo=azuredevops&logoColor=white)](https://azure.microsoft.com/en-us/products/devops/)
[![Security](https://img.shields.io/badge/Security-Trivy%200%20CVEs%20%7C%20CIS%20Hardened-00C7B7?logo=aqua&logoColor=white)](https://www.aquasec.com/products/trivy/)
[![Observability](https://img.shields.io/badge/Observability-Prometheus%20%7C%20Grafana%20%7C%20Loki-F46800?logo=grafana&logoColor=white)](https://grafana.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

---

## 📌 Executive Summary & FinOps Value

Cloud waste averages **25%–35% of enterprise cloud spend**, driven by orphaned public IP addresses, unattached virtual disks, mistagged test environments, and abandoned compute instances. 

**InfraReaper** is a production-grade, enterprise DevOps portfolio solution that continuously inspects, audits, alerts, and safely purges orphaned and expired cloud infrastructure across Microsoft Azure:
- **Zero Accidental Destruction**: Built-in dry-run simulation mode, protected resource lists, and 48-hour expiration grace periods.
- **FinOps Cost Attribution**: Real-time identification of zombie assets, projecting monthly waste avoidance.
- **Full-Stack Observability**: Native Prometheus exposition, Loki log aggregation, and 6 auto-provisioned Grafana production dashboards.
- **100% Automated CI/CD**: Multi-stage Azure DevOps pipeline executing on a hardened self-hosted lab agent with end-to-end smoke tests on live AKS clusters.

---

## 🏗️ Architecture

```
                       ┌───────────────────────────────────────────────────────────────┐
                       │                   Azure Cloud Infrastructure                  │
                       │                                                               │
┌──────────────────┐   │  ┌───────────────────────┐       ┌─────────────────────────┐  │
│  Ubuntu 24.04    │   │  │ Azure Container Reg   │       │     Azure Key Vault     │  │
│  Lab Server      │   │  │ (infrareaperacrpalwa) │       │   (infrareaperkv-*)     │  │
│                  │   │  └───────────▲───────────┘       └────────────▲────────────┘  │
│ ┌──────────────┐ │   │              │ Image Push                     │ Secrets Sync  │
│ │AzDO Agent    │─┼───┼──────────────┼────────────────────────────────┼───────────────┤
│ │(Self-Hosted) │ │   │              ▼                                ▼               │
│ └──────────────┘ │   │  ┌─────────────────────────────────────────────────────────┐  │
│ ┌──────────────┐ │   │  │             Azure Kubernetes Service (AKS)              │  │
│ │Ansible Play  │─┼───┤  │                                                         │  │
│ └──────────────┘ │   │  │   ┌─────────────────────────────────────────────────┐   │  │
└──────────────────┘   │  │   │            Namespace: infrareaper               │   │  │
                       │  │   │                                                 │   │  │
                       │  │   │  ┌───────────────────┐    ┌──────────────────┐  │   │  │
                       │  │   │  │ InfraReaper       │───►│ Pushgateway      │  │   │  │
                       │  │   │  │ Scanner CronJob   │    │ (Port 9091)      │  │   │  │
                       │  │   │  └─────────┬─────────┘    └────────┬─────────┘  │   │  │
                       │  │   │            │ Logs                  │ Scrapes    │   │  │
                       │  │   │            ▼                       ▼            │   │  │
                       │  │   │  ┌───────────────────┐    ┌──────────────────┐  │   │  │
                       │  │   │  │ Promtail DaemonSet│    │ Prometheus Core  │  │   │  │
                       │  │   │  └─────────┬─────────┘    │ (Port 9090)      │  │   │  │
                       │  │   │            │ Streams      └────────┬─────────┘  │   │  │
                       │  │   │            ▼                       │ Metrics    │   │  │
                       │  │   │  ┌───────────────────┐             │            │   │  │
                       │  │   │  │ Loki Storage      │◄────────────┤            │   │  │
                       │  │   │  │ (Port 3100)       │             ▼            │   │  │
                       │  │   │  └─────────┬─────────┘    ┌──────────────────┐  │   │  │
                       │  │   │            └─────────────►│ Grafana UI       │  │   │  │
                       │  │   │               LogQL       │ (6 Dashboards)   │  │   │  │
                       │  │   │                           └──────────────────┘  │   │  │
                       │  │   └─────────────────────────────────────────────────┘   │  │
                       │  └─────────────────────────────────────────────────────────┘  │
                       └───────────────────────────────────────────────────────────────┘
```

---

## ⚡ 10-Phase Implementation Roadmap

| Phase | Milestone | Focus Areas | Status |
| :---: | :--- | :--- | :---: |
| **01** | **Problem Definition** | FinOps governance metrics, tag taxonomy, lifecycle states | Completed |
| **02** | **Architecture Design** | Micro-architecture, network policies, least privilege RBAC | Completed |
| **03** | **Git & Workflow Setup** | Feature-branching workflow, pre-commit hooks, linting rules | Completed |
| **04** | **Ansible Lab Server** | Ubuntu 24.04 hardening, toolchain, self-hosted AzDO agent | Completed |
| **05** | **Terraform Infrastructure**| 35 Azure resources: AKS, ACR, Key Vault, VNet, Test targets | Completed |
| **06** | **Scanner Core Engine** | Bash + `az cli` + `jq`, policy evaluation, cleanup engine | Completed |
| **07** | **Docker Hardening** | Azure Linux 3.0 base, non-root UID 10001, Trivy CVE mitigation | Completed |
| **08** | **Kubernetes Manifests** | Batch CronJob, NetworkPolicy, Kustomize dev/prod overlays | Completed |
| **09** | **Azure DevOps CI/CD** | 5-stage automated pipeline: Lint, Scan, Build, Deploy, Smoke Test | Completed |
| **10** | **Observability Stack** | Prometheus, Pushgateway, Alertmanager, Loki, 6 Grafana boards | Completed |

---

## 📊 The 6 Production Grafana Dashboards

The monitoring stack includes 6 pre-provisioned dashboards loaded directly into Grafana:

1. **`1. InfraReaper - Scanner SLO & Availability`**: Live calculation of scanner availability against the **99.0% SLO target**, error budget burn rate, and latency tracking (~100s).
2. **`2. InfraReaper - Tag & Policy Governance Compliance`**: Percentage score (30%) based on mandatory tags (`Environment`, `Owner`, `Project`, `CostCenter`, `ExpireDate`), tracking Critical (7) vs. Warning (14) violations.
3. **`3. InfraReaper - Cloud Resource Inventory`**: 10 discovered cloud assets, tracking 2 orphaned resources (`test-orphan-ip`, `test-unattached-disk`), and compliance ratios.
4. **`4. InfraReaper - Resource Lifecycle & Expiry States`**: Warning windows (7d, 72h, 24h), 48h grace periods, and simulated (dry-run) vs. real purge counters.
5. **`5. InfraReaper - Cloud Cost & Waste Attribution`**: FinOps waste estimation, projecting monthly savings from purging idle public IPs and unattached disks.
6. **`6. InfraReaper - Scanner System Health & Logs`**: Component health (Pushgateway `UP`, Prometheus `UP`) with an embedded real-time LogQL terminal powered by Loki.

---

## 🚀 Developer Quick Start

```bash
# 1. Lint everything
make lint

# 2. Run scanner unit test suite
make test-scripts

# 3. Security scans with Trivy
make scan

# 4. Deploy Dev overlay to AKS
make deploy

# 5. Deploy the full observability stack (Prometheus, Grafana, Loki)
make deploy-monitoring

# 6. Forward Grafana to localhost (port 3000)
make port-forward-grafana
```

---

## 📖 Complete Documentation

- [Architecture Specification](docs/architecture.md)
- [Requirements & Specifications](docs/requirements.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Monitoring & Observability Guide](docs/monitoring-guide.md)
- [Security & Threat Model](docs/security-model.md)
- [Operations & Troubleshooting Runbook](docs/runbook.md)

---

## 📄 License

This project is licensed under the [MIT License](../LICENSE).
