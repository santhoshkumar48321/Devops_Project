# InfraReaper — Architecture Document

> **Version:** 1.0  
> **Author:** Santhosh  
> **Date:** 2026-10-12  
> **Status:** Draft  

---

## 1. Architecture Overview

InfraReaper follows a **scan → evaluate → notify → cleanup → report** pipeline architecture. The scanner runs as a Kubernetes CronJob on AKS, executes Bash scripts that interact with Azure via `az cli`, and pushes results to a Prometheus-based observability stack.

### 1.1 High-Level Architecture

```
┌──────────────────────── Lab Server (Ubuntu 24.04) ─────────────────────────┐
│  4 CPU | 32 GB RAM | 1 TB Storage                                          │
│                                                                             │
│  ┌─────────────────────────────────────────┐                               │
│  │  Azure DevOps Self-Hosted Agent         │── Runs CI/CD pipelines ──────►│
│  │  Tools: az, terraform, ansible, docker, │                               │
│  │         kubectl, helm, trivy, jq        │                               │
│  └─────────────────────────────────────────┘                               │
│                                                                             │
│  ┌─────────────────────────────────────────┐                               │
│  │  Ansible Control Node                   │── Configures this server      │
│  │  (localhost + future remote targets)    │   and provisions agents       │
│  └─────────────────────────────────────────┘                               │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                    Pipeline pushes images to ACR
                    Pipeline deploys manifests to AKS
                              │
                              ▼
┌──────────────────────── Azure Cloud ───────────────────────────────────────┐
│                                                                            │
│  ┌── AKS Cluster ──────────────────────────────────────────────────────┐  │
│  │  Control Plane: Free tier                                           │  │
│  │  Node Pool: 1× Standard_B2s (2 vCPU, 4 GB RAM)                    │  │
│  │  Namespace: infrareaper                                             │  │
│  │                                                                     │  │
│  │  ┌─────────────────┐    ┌─────────────────┐   ┌────────────────┐   │  │
│  │  │ Scanner CronJob │───►│ Pushgateway     │◄──│ Prometheus     │   │  │
│  │  │ (every 30 min)  │    │ (receive metrics)│   │ (scrape & store)│  │  │
│  │  └────────┬────────┘    └─────────────────┘   └───────┬────────┘   │  │
│  │           │                                           │             │  │
│  │           │ sends email                    scrapes     │             │  │
│  │           ▼                                           ▼             │  │
│  │  ┌─────────────────┐                      ┌────────────────┐       │  │
│  │  │ SendGrid API    │                      │ Grafana        │       │  │
│  │  │ (external)      │                      │ (dashboards +  │       │  │
│  │  └─────────────────┘                      │  SSO via Entra)│       │  │
│  │                                           └────────────────┘       │  │
│  │  ┌─────────────────┐   ┌──────────────────┐                       │  │
│  │  │ Loki            │◄──│ Promtail         │                       │  │
│  │  │ (log storage)   │   │ (log collector)  │                       │  │
│  │  └────────┬────────┘   └──────────────────┘                       │  │
│  │           │                                                        │  │
│  │           └───────────► Grafana (log queries via LogQL)            │  │
│  │                                                                     │  │
│  │  ┌─────────────────┐                                               │  │
│  │  │ AlertManager    │── Routes alerts → SendGrid → Email            │  │
│  │  └─────────────────┘                                               │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  ┌── Supporting Services ──────────────────────────────────────────────┐  │
│  │                                                                     │  │
│  │  ACR ──────────── Stores scanner Docker images                     │  │
│  │  Key Vault ────── Stores SP credentials + SendGrid API key         │  │
│  │  Entra ID ─────── Service principals, RBAC, Grafana SSO            │  │
│  │  Azure DevOps ─── CI/CD pipelines (free tier)                      │  │
│  │  Storage Acct ─── Terraform remote state (blob + locking)          │  │
│  │  Budget Alerts ── $10 / $25 / $50 / $75 thresholds                 │  │
│  │                                                                     │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  ┌── Test Resources (InfraReaper targets) ─────────────────────────────┐  │
│  │  Resource Group: "infrareaper-test-resources"                       │  │
│  │                                                                     │  │
│  │  • VM "test-vm-tagged" (B1s) ─── owner=santhosh, env=test,         │  │
│  │                                   expiry-date=2026-10-20            │  │
│  │  • VM "test-vm-untagged" (B1s) ── NO tags                          │  │
│  │  • Storage "teststorageexpired" ── expiry-date=2026-10-01 (past)   │  │
│  │  • Public IP "test-orphan-ip" ──── no NIC attached, no tags        │  │
│  │  • Disk "test-unattached-disk" ─── not attached to any VM          │  │
│  │                                                                     │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Flow

### 2.1 Scan Pipeline Flow

This is the core data flow — what happens every 30 minutes when the CronJob triggers:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        SCAN PIPELINE (every 30 min)                      │
│                                                                          │
│  ┌──────────┐    ┌───────────┐    ┌──────────┐    ┌──────────────────┐  │
│  │ 1. AUTH  │───►│ 2. SCAN   │───►│ 3. EVAL  │───►│ 4. CHECK EXPIRY │  │
│  │          │    │           │    │          │    │                  │  │
│  │ Login to │    │ az resource│    │ Compare  │    │ Parse dates      │  │
│  │ Azure    │    │ list      │    │ tags vs  │    │ Calculate TTL    │  │
│  │ via SP   │    │ Collect   │    │ policies │    │ Identify expired │  │
│  └──────────┘    │ metadata  │    │ Score    │    │ + expiring soon  │  │
│                  └───────────┘    └──────────┘    └──────────────────┘  │
│                                                          │              │
│                                                          ▼              │
│  ┌──────────────┐    ┌───────────┐    ┌──────────────────────────────┐  │
│  │ 6. METRICS   │◄───│ 5b.CLEAN │◄───│ 5a. NOTIFY                   │  │
│  │              │    │           │    │                              │  │
│  │ Push to      │    │ Check     │    │ Send emails via SendGrid     │  │
│  │ Pushgateway  │    │ protected │    │ - Violations                 │  │
│  │ - counts     │    │ list      │    │ - Expiry warnings            │  │
│  │ - compliance │    │ Dealloc   │    │ - Cleanup confirmations      │  │
│  │ - duration   │    │ + Delete  │    │                              │  │
│  │ - status     │    │ Audit log │    │                              │  │
│  └──────────────┘    └───────────┘    └──────────────────────────────┘  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Step-by-Step Data Flow

| Step | Script | Input | Processing | Output |
|---|---|---|---|---|
| 1 | `scan.sh` | SP credentials from Key Vault (via K8s Secret) | `az login --service-principal` | Authenticated Azure session |
| 2 | `scan.sh` | Authenticated session, target resource groups | `az resource list --resource-group <rg> -o json` | JSON array of all resources with metadata |
| 3 | `evaluate-policies.sh` | Resource JSON, `tag-policies.yaml` | For each resource: check required tags exist, validate values | Compliance report: compliant[], non-compliant[], violations[] |
| 4 | `check-expiry.sh` | Resource JSON, `lifecycle-rules.yaml` | Parse `expiry-date` tag, compare to current date, apply grace period | Expired[], expiring-soon[], active[] |
| 5a | `notify.sh` | Violations, expired resources | Build email body, call SendGrid API via `curl` | Emails sent, notification log |
| 5b | `cleanup.sh` | Expired resources (past grace period), `protected-resources.yaml` | Check protected list → deallocate VM → delete resource | Cleanup audit log, success/failure counts |
| 6 | `push-metrics.sh` | All counts from steps 2–5 | Format as Prometheus metrics, `curl` POST to Pushgateway | Metrics available for Prometheus to scrape |

### 2.3 Observability Data Flow

```
Scanner Pod                    Observability Stack              User
───────────                    ───────────────────              ────
    │                                                            │
    │──── stdout/stderr ──────► Promtail ──► Loki ──────────────►│ (Grafana: LogQL)
    │                                                            │
    │──── metrics (curl) ─────► Pushgateway ──► Prometheus ─────►│ (Grafana: PromQL)
    │                                                            │
    │                           AlertManager ──► SendGrid ──────►│ (Email)
    │                                                            │
```

---

## 3. Component Details

### 3.1 Scanner CronJob

| Property | Value |
|---|---|
| **Type** | Kubernetes CronJob |
| **Schedule** | `*/30 * * * *` (every 30 minutes) |
| **Namespace** | `infrareaper` |
| **Image** | `<acr-name>.azurecr.io/infrareaper-scanner:latest` |
| **Resources** | Request: 128Mi / 100m — Limit: 256Mi / 250m |
| **Restart Policy** | `OnFailure` (max 3 retries) |
| **Concurrency Policy** | `Forbid` (skip if previous run still active) |
| **History Limits** | 3 successful, 3 failed |
| **Service Account** | `infrareaper-scanner` (with RBAC for secrets access) |
| **Secrets Source** | Kubernetes Secrets synced from Key Vault via External Secrets Operator (or CSI driver) |

### 3.2 Service Principals

| SP Name | Role | Scope | Purpose |
|---|---|---|---|
| `sp-infrareaper-scanner` | Reader | Subscription | Read all resource metadata and tags |
| `sp-infrareaper-cleanup` | Contributor | Resource Group: `infrareaper-test-resources` | Delete/deallocate expired test resources |
| `sp-grafana-sso` | N/A (app registration only) | N/A | OAuth2 app for Grafana SSO via Entra ID |

### 3.3 Networking

```
┌── AKS VNet (10.0.0.0/16) ──────────────────────────────┐
│                                                          │
│  ┌── System Subnet (10.0.1.0/24) ───────────────────┐  │
│  │  AKS node pool (Standard_B2s)                     │  │
│  │  All pods run here (single node)                  │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  NSG Rules:                                              │
│  • Allow outbound to Azure Resource Manager API (443)   │
│  • Allow outbound to SendGrid API (443)                 │
│  • Allow outbound to ACR (443)                          │
│  • Allow inbound to Grafana (LoadBalancer or Ingress)   │
│  • Deny all other inbound from internet                 │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### 3.4 Kubernetes Network Policies

```yaml
# Scanner pod egress rules:
# ✅ Allow → Pushgateway (port 9091, within cluster)
# ✅ Allow → Azure ARM API (external, port 443)
# ✅ Allow → SendGrid API (external, port 443)
# ✅ Allow → DNS (port 53, kube-dns)
# ❌ Deny → all other traffic

# Pushgateway ingress rules:
# ✅ Allow ← Scanner pod (port 9091)
# ✅ Allow ← Prometheus (port 9091, for scraping)
# ❌ Deny ← all other traffic
```

---

## 4. Technology Decisions

Each technology choice has a deliberate rationale. This section prepares you for the interview question: *"Why did you choose X over Y?"*

### 4.1 Decision Records

| Decision | Chosen | Alternatives Considered | Rationale |
|---|---|---|---|
| **Scanner language** | Bash + `az cli` + `jq` | Python + Azure SDK, Go + Azure SDK | DevOps portfolio should showcase CLI mastery. Bash keeps the app simple so infrastructure shines. Python/Go would shift focus to application development. |
| **Orchestration** | Kubernetes CronJob on AKS | Azure Functions (Timer), Azure Automation, Linux cron on VM | K8s CronJob demonstrates Kubernetes skills. Azure Functions would hide infrastructure. Linux cron doesn't demonstrate container orchestration. |
| **Container registry** | ACR (Azure Container Registry) | Docker Hub, GitHub Container Registry | ACR integrates natively with AKS (no image pull secrets needed with managed identity). Keeps everything in Azure ecosystem. |
| **Secrets management** | Azure Key Vault + K8s Secrets (synced) | K8s Secrets only, HashiCorp Vault, SOPS | Key Vault is the Azure-native solution. Demonstrates cloud secrets management. HashiCorp Vault is overkill for this scale. |
| **Monitoring** | Prometheus + Grafana (self-hosted on AKS) | Azure Monitor + Application Insights, Datadog | Self-hosted demonstrates hands-on Prometheus/Grafana skills. Azure Monitor would hide the complexity. These are the most common tools in DevOps roles. |
| **Logging** | Loki + Promtail | ELK Stack (Elasticsearch + Logstash + Kibana), Azure Log Analytics | Loki is lightweight, designed for Kubernetes, uses LogQL (similar to PromQL). ELK requires too much memory for B2s node. |
| **Notifications** | SendGrid (email) | Slack webhooks, PagerDuty, Azure Communication Services | Email is universal. SendGrid has a free tier (100/day). Slack/PagerDuty would require additional accounts. |
| **CI/CD** | Azure DevOps Pipelines | GitHub Actions, Jenkins, GitLab CI | Azure DevOps is enterprise-standard, demonstrates proficiency with Microsoft stack, integrates with Azure natively. |
| **IaC** | Terraform | Bicep, ARM Templates, Pulumi | Terraform is cloud-agnostic (transferable skill), most in-demand IaC tool, and the one you're learning. Bicep is Azure-only. |
| **Configuration management** | Ansible | Chef, Puppet, SaltStack | Ansible is agentless (no agent to install on targets), uses YAML (readable), and is the most common CM tool for Linux. |

---

## 5. Resource Group Layout

```
Azure Subscription
│
├── infrareaper-state-rg          # Terraform state backend
│   └── Storage Account           # tfstate blob container with locking
│
├── infrareaper-core-rg           # Core infrastructure
│   ├── AKS Cluster               # Scanner + monitoring workloads
│   ├── ACR                       # Container images
│   ├── Key Vault                 # Secrets
│   ├── VNet + Subnets + NSGs     # Networking
│   └── Budget Alerts             # Cost monitoring
│
└── infrareaper-test-resources    # Test resources (scanner targets)
    ├── VM: test-vm-tagged        # Properly tagged
    ├── VM: test-vm-untagged      # Missing tags (violation)
    ├── Storage: teststorageexp   # Expired tag (cleanup target)
    ├── Public IP: test-orphan-ip # Orphaned (no NIC, no tags)
    └── Disk: test-unattached     # Unattached managed disk
```

**Why 3 resource groups?**
- **State RG** is created manually ONCE (bootstrapping — before Terraform can manage itself).
- **Core RG** contains everything Terraform manages for InfraReaper's infrastructure.
- **Test RG** isolates the resources InfraReaper scans/cleans. The cleanup SP has Contributor ONLY on this RG — it can never touch core infrastructure.

---

## 6. Failure Modes & Resilience

| Failure | Impact | Mitigation |
|---|---|---|
| **Azure API unavailable** | Scan fails | CronJob retries (max 3). Alert fires if no scan in 2 hours. Next scheduled scan runs independently. |
| **SP credentials expired** | Authentication fails, all scans fail | Alert fires. Key Vault secret rotation (document in runbook). |
| **Pushgateway down** | Metrics not recorded | Scanner still completes. Metric push failure is logged, not fatal. Gap visible in Grafana. |
| **SendGrid down** | No email notifications | Notification failure is logged, not fatal. Scan still succeeds. Violations still visible in Grafana. |
| **AKS node out of memory** | Pod evicted, scan fails | Resource limits prevent the scanner from consuming too much. Alert fires on repeated failures. |
| **Cleanup deletes wrong resource** | Data loss | Protected resources list. Dry-run mode. Cleanup SP scoped to test RG only. Audit log for every action. |
| **CronJob overlap** | Duplicate scan, potential conflicts | `concurrencyPolicy: Forbid` skips if previous run is active. |
| **Key Vault inaccessible** | Can't retrieve secrets | Pod fails to start. CronJob retry policy. Alert fires. |
| **ACR image pull fails** | Pod can't start | AKS-ACR integration (managed identity). Alert fires on pod failures. |
| **Network policy misconfigured** | Scanner can't reach Azure or Pushgateway | Test network policies in dev overlay first. Document allowed flows. |

---

## 7. Deployment Environments

| Property | Dev (overlay) | Prod (overlay) |
|---|---|---|
| **Scan schedule** | `*/30 * * * *` (every 30 min) | `*/30 * * * *` (every 30 min) |
| **Cleanup mode** | `DRY_RUN=true` (log only) | `DRY_RUN=false` (actually delete) |
| **Notification recipients** | Your email only | Team distribution list |
| **Log level** | `DEBUG` | `INFO` |
| **Resource limits** | Lower (128Mi / 100m) | Standard (256Mi / 250m) |
| **Target resource groups** | `infrareaper-test-resources` | `infrareaper-test-resources` |
| **Image tag** | `dev-<commit-sha>` | `<semver>` (e.g., `1.0.0`) |

> **Note:** For this portfolio project, "dev" and "prod" are logical overlays (Kustomize), not separate Azure subscriptions. They demonstrate the pattern of environment-specific configuration.

---

## 8. Cost Architecture

| Resource | SKU/Tier | Monthly Cost | Notes |
|---|---|---|---|
| AKS Control Plane | Free | \$0 | No SLA, sufficient for portfolio |
| AKS Node Pool | 1× Standard_B2s | ~\$30 | 2 vCPU, 4 GB RAM. Stop when not working. |
| ACR | Basic | ~\$5 | 10 GB storage included |
| Key Vault | Standard | ~\$0.50 | Pay per operation (negligible) |
| Storage (TF state) | Standard LRS | ~\$0.10 | Tiny blob, negligible cost |
| Test VM × 2 | B1s | ~\$8–16 | Deallocate when not actively testing |
| Public IP | Standard | ~\$3 | Only when VM running |
| Budget Alerts | — | \$0 | Built into Azure |
| SendGrid | Free tier | \$0 | 100 emails/day |
| **Estimated total** | | **\$45–55/month** | **With cost-saving practices** |

**Cost-saving rules:**
1. `az aks nodepool scale --node-count 0` at end of each work day (saves ~\$1/day)
2. `az vm deallocate` test VMs when not testing (saves ~\$0.50/day)
3. Delete test resources entirely when not in Phase 6+ testing

---

## 9. Security Architecture

```
┌── Identity & Access ──────────────────────────────────────────────┐
│                                                                    │
│  Entra ID                                                          │
│  ├── SP: sp-infrareaper-scanner ── Reader @ Subscription           │
│  ├── SP: sp-infrareaper-cleanup ── Contributor @ Test RG only      │
│  ├── App: grafana-sso ──────────── OAuth2/OIDC for Grafana login   │
│  ├── Group: infrareaper-admins ─── Grafana Admin role mapping      │
│  └── Group: infrareaper-viewers ── Grafana Viewer role mapping     │
│                                                                    │
├── Secrets Flow ───────────────────────────────────────────────────┤
│                                                                    │
│  Key Vault ──► External Secrets / CSI ──► K8s Secrets ──► Pod Env  │
│  (source of       (sync mechanism)        (consumed by     │
│   truth)                                   scanner pod)    │
│                                                                    │
│  Stored secrets:                                                   │
│  • AZURE_CLIENT_ID (scanner SP)                                    │
│  • AZURE_CLIENT_SECRET (scanner SP)                                │
│  • AZURE_TENANT_ID                                                 │
│  • CLEANUP_CLIENT_ID (cleanup SP)                                  │
│  • CLEANUP_CLIENT_SECRET (cleanup SP)                              │
│  • SENDGRID_API_KEY                                                │
│                                                                    │
├── Network Security ───────────────────────────────────────────────┤
│                                                                    │
│  AKS VNet ── NSG ── only allow required outbound traffic           │
│  K8s NetworkPolicies ── restrict pod-to-pod communication          │
│  No public ingress except Grafana (LoadBalancer with IP restrict)  │
│                                                                    │
├── Pipeline Security ──────────────────────────────────────────────┤
│                                                                    │
│  Azure DevOps Service Connections ── via Entra ID (not PATs)       │
│  No secrets in pipeline YAML ── Key Vault linked variable groups   │
│  IaC scanning (Trivy) ── every PR                                  │
│  Image scanning (Trivy) ── every build, fail on CRITICAL/HIGH     │
│                                                                    │
├── Runtime Safety ─────────────────────────────────────────────────┤
│                                                                    │
│  protected-resources.yaml ── never-delete list checked before      │
│                               every cleanup action                 │
│  Dry-run mode ── default in dev, opt-in in prod                    │
│  Audit logging ── every cleanup action logged with full details    │
│  Resource locks ── scanner checks for CanNotDelete / ReadOnly      │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 10. Future Extensibility

These are deliberately out of scope for v1 but the architecture supports them:

| Extension | How Architecture Supports It |
|---|---|
| **AWS scanning** | Add `aws-scan.sh` alongside `scan.sh`. Same pipeline pattern, different CLI (`aws` instead of `az`). Metrics pushed to same Pushgateway. |
| **Multi-subscription** | Parameterize subscription ID in config. Scanner loops over subscription list. |
| **Event-driven scanning** | Add Azure Event Grid trigger → webhook → on-demand K8s Job (in addition to CronJob). |
| **Slack/Teams notifications** | Add webhook URL to notify.sh. Send to multiple channels based on severity. |
| **Web dashboard** | Add a lightweight API (Flask/Express) that reads from Prometheus API. Not planned. |
| **Database for history** | Add PostgreSQL. Store scan results for long-term trending beyond Prometheus retention. |

---

## Revision History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-10-12 | Santhosh | Initial architecture document — Phase 2. |
