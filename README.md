# InfraReaper 🪦

**Autonomous Cloud Resource Lifecycle, Governance & FinOps Engine on Microsoft Azure**

[![Azure](https://img.shields.io/badge/Azure-AKS%20%7C%20ACR%20%7C%20KeyVault-0078D4?logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform%20v1.12-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Config-Ansible%20Lab%20Automation-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes%20Kustomize-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-Azure%20DevOps%20Pipelines-0078D4?logo=azuredevops&logoColor=white)](https://azure.microsoft.com/en-us/products/devops/)
[![Security](https://img.shields.io/badge/Security-Trivy%200%20CVEs%20%7C%20CIS%20Hardened-00C7B7?logo=aqua&logoColor=white)](https://www.aquasec.com/products/trivy/)
[![Observability](https://img.shields.io/badge/Observability-Prometheus%20%7C%20Grafana%20%7C%20Loki-F46800?logo=grafana&logoColor=white)](https://grafana.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 📌 Executive Summary & FinOps Value

Cloud waste averages **25%–35% of enterprise cloud spend**, driven by orphaned public IP addresses, unattached virtual disks, mistagged test environments, and abandoned compute instances. 

**InfraReaper** is a production-grade, enterprise DevOps portfolio solution that continuously inspects, audits, alerts, and safely purges orphaned and expired cloud infrastructure across Microsoft Azure:
- **Zero Accidental Destruction**: Built-in dry-run simulation mode, protected resource lists, and 48-hour expiration grace periods.
- **FinOps Cost Attribution**: Real-time identification of zombie assets, projecting monthly waste avoidance.
- **Full-Stack Observability**: Native Prometheus exposition, Loki log aggregation, and 6 auto-provisioned Grafana production dashboards.
- **100% Automated CI/CD**: Multi-stage Azure DevOps pipeline executing on a hardened self-hosted lab agent with end-to-end smoke tests on live AKS clusters.

---

## 🏗️ End-to-End System Architecture

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

| Phase | Milestone | Focus Areas | Verification |
| :---: | :--- | :--- | :--- |
| **01** | **Problem Definition** | FinOps governance metrics, tag taxonomy, lifecycle states | Documentation & spec sign-off |
| **02** | **Architecture Design** | Micro-architecture, network policies, least privilege RBAC | Architecture & security diagrams |
| **03** | **Git & Workflow Setup** | Feature-branching workflow, pre-commit hooks, linting rules | Multi-branch Git automation |
| **04** | **Ansible Lab Server** | Ubuntu 24.04 hardening, toolchain, self-hosted AzDO agent | Idempotent agent provisioning |
| **05** | **Terraform Infrastructure**| 35 Azure resources: AKS, ACR, Key Vault, VNet, Test targets | Clean plan/apply, 0 drift |
| **06** | **Scanner Core Engine** | Bash + `az cli` + `jq`, policy evaluation, cleanup engine | 10/10 test suite passing |
| **07** | **Docker Hardening** | Azure Linux 3.0 base, non-root UID 10001, Trivy CVE mitigation | **0 Critical / 0 High CVEs** |
| **08** | **Kubernetes Manifests** | Batch CronJob, NetworkPolicy, Kustomize dev/prod overlays | Live execution verified on AKS |
| **09** | **Azure DevOps CI/CD** | 5-stage automated pipeline: Lint, Scan, Build, Deploy, Smoke Test | End-to-end pipeline green |
| **10** | **Observability Stack** | Prometheus, Pushgateway, Alertmanager, Loki, 6 Grafana boards | Live metrics & LogQL logs |

---

## 📊 The 6 Production Grafana Dashboards

The monitoring stack includes 6 pre-provisioned dashboards loaded directly into Grafana:

1. **`1. InfraReaper - Scanner SLO & Availability`**
   - **Availability Gauge**: Live calculation of scanner availability against the **99.0% SLO target**.
   - **Error Budget**: Real-time error budget consumption and burn rate.
   - **Latency Tracking**: Average and P95 scan execution duration (~100s).
2. **`2. InfraReaper - Tag & Policy Governance Compliance`**
   - **Compliance Score**: Percentage score based on mandatory tags (`Environment`, `Owner`, `Project`, `CostCenter`, `ExpireDate`).
   - **Violations by Severity**: Critical (7) vs. Warning (14) vs. Info.
3. **`3. InfraReaper - Cloud Resource Inventory`**
   - **Discovered Cloud Assets**: Total inventory count across target resource groups.
   - **Orphan Ratio**: Tracking unassociated public IPs and unattached managed disks.
4. **`4. InfraReaper - Resource Lifecycle & Expiry States`**
   - **Warning Windows**: Assets expiring within 7 days, 72 hours, and 24 hours.
   - **Grace Period Tracking**: Assets past expiry within the 48-hour deallocation grace window.
   - **Cleanups**: Simulated (Dry-Run) vs. Real Purges.
5. **`5. InfraReaper - Cloud Cost & Waste Attribution`**
   - **Projected Waste Avoidance**: Financial estimation of idle waste prevented ($USD/month).
   - **Asset Retention**: Trend of purged vs. retained cloud assets.
6. **`6. InfraReaper - Scanner System Health & Logs`**
   - **Service Health**: Pushgateway (`UP`), Prometheus (`UP`).
   - **Live LogQL Stream**: Embedded real-time scanner pod log terminal powered by Loki and Promtail.

---

## 🚀 Quick Start & Local Execution

The project provides unified `make` targets for developer workflows:

```bash
cd infrareaper

# 1. Lint shell scripts, Dockerfile, Terraform, and YAML
make lint

# 2. Run the scanner engine test suite (10 unit tests)
make test-scripts

# 3. Scan container images and IaC configs with Trivy
make scan

# 4. Deploy Dev overlay to AKS
make deploy

# 5. Deploy the full observability stack (Prometheus, Grafana, Loki)
make deploy-monitoring

# 6. Forward Grafana to localhost
make port-forward-grafana
```

---

## 🔄 Multi-Stage Azure DevOps CI/CD Pipeline

The pipeline (`azure-pipelines.yml`) runs on the self-hosted lab agent (`infrareaper-lab-agent`):

```
Stage 1: Lint & Validate
  ├── ShellCheck (scripts/*.sh)
  ├── Hadolint (docker/Dockerfile)
  ├── Yamllint (policies/ & kubernetes/)
  ├── Terraform fmt & validate
  ├── Kustomize build validate (base, dev, prod, monitoring)
  └── Scanner engine unit test suite (10/10)
Stage 2: Security & IaC Scanning
  ├── Trivy Kubernetes CIS configuration audit
  ├── Trivy Terraform IaC misconfiguration scan
  └── Trivy secret detection
Stage 3: Container Build & Layer Scan
  ├── Docker build tagged with $(Build.BuildId) and :dev
  ├── Trivy container image scan (0 Critical / 0 High CVEs)
  └── Docker push to Azure Container Registry
Stage 4: Continuous Deployment to AKS
  ├── kubectl connect to AKS (infrareaper-aks)
  ├── Apply Kustomize overlays (dev)
  ├── Synchronize live Service Principal secrets from Azure Key Vault
  └── Deploy Observability Stack
Stage 5: Live Smoke Test Verification
  ├── Trigger on-demand test Job from CronJob
  ├── Wait for pod completion & assert exit code 0
  ├── Verify Prometheus Pushgateway ingestion
  ├── Stream execution logs to pipeline console
  └── Delete ephemeral test job
```

---

## 📁 Repository Directory Layout

```
Devops_Project/
├── azure-pipelines.yml                       # Root CI/CD pipeline entrypoint
└── infrareaper/
    ├── Makefile                              # Developer & CI command orchestration
    ├── .trivyignore                          # Documented CVE suppression baseline
    ├── .hadolint.yaml                        # Dockerfile linting rules
    ├── ansible/                              # Lab server configuration & AzDO agent role
    ├── docker/                               # Hardened non-root Dockerfile (Azure Linux 3.0)
    ├── docs/                                 # Architecture, requirements, runbooks, guides
    │   ├── architecture.md                   # Micro-architecture & network topology
    │   ├── requirements.md                   # Functional & non-functional requirements
    │   ├── deployment-guide.md               # End-to-end installation runbook
    │   ├── monitoring-guide.md               # Metrics dictionary & dashboard architecture
    │   ├── security-model.md                 # Least-privilege RBAC & network security
    │   └── runbook.md                        # Operations & disaster recovery runbook
    ├── kubernetes/                           # K8s manifests & Kustomize overlays
    │   ├── base/                             # CronJob, ServiceAccount, NetworkPolicy, ConfigMaps
    │   ├── overlays/dev/                     # DRY_RUN=true, image:dev
    │   ├── overlays/prod/                    # DRY_RUN=false, image:v1.0.0
    │   └── monitoring/                       # Prometheus, Pushgateway, Alertmanager, Loki, Grafana
    ├── pipelines/                            # Azure DevOps multi-stage pipeline templates
    ├── policies/                             # Tag policies, lifecycle rules, protected resources
    ├── scripts/                              # Core scanner engine (Bash + az + jq)
    ├── terraform/                            # Modular cloud infrastructure (dev/prod)
    └── tests/                                # Test suites for scanner & policies
```

---

## 🔒 Security & Compliance Standards

- **Least Privilege Identity**: The scanner accesses Azure via a scoped Service Principal with limited Contributor rights confined to test resource groups.
- **Zero Ingress Pod Network**: Container pods run with zero listening ports. Ingress is blocked via Kubernetes `NetworkPolicy`.
- **Read-Only Root Filesystem**: Scanner containers mount `/` as read-only. Dynamic reports write strictly to ephemeral `emptyDir` scratch volumes.
- **Secrets Management**: Zero credentials in Git or plain text. Secrets are synced dynamically from **Azure Key Vault** into Kubernetes Secrets at deploy time.
- **Vulnerability Management**: Scanned with **Trivy** in CI/CD; upstream base image CVEs are tracked and documented in `.trivyignore`.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
