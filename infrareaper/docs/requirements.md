# InfraReaper — Requirements Document

> **Version:** 1.0  
> **Author:** Santhosh  
> **Date:** 2026-10-04  
> **Status:** Draft  

---

## 1. Business Problem

### 1.1 Problem Statement

Cloud infrastructure waste is a systemic problem across organizations of all sizes. Industry research consistently shows that **25–35% of total cloud spend is wasted** on idle, forgotten, or orphaned resources.

The root cause is a gap between **resource creation** and **resource lifecycle management**:

- Engineers spin up VMs, storage accounts, databases, and public IPs for development, testing, or proof-of-concept work.
- Once the task is done, the resources are forgotten — they remain running and billing.
- Tags (owner, environment, expiry) are missing or inconsistent, making it impossible to identify who owns what.
- There is no automated enforcement of tagging policies or resource expiry.
- The monthly cloud bill grows silently until someone manually audits it — a reactive, error-prone process.

### 1.2 Business Impact

| Impact Area | Description |
|---|---|
| **Financial** | Wasted spend on unused resources directly reduces budget available for productive workloads. |
| **Operational** | Manual audits are time-consuming, inconsistent, and don't scale with resource count. |
| **Security** | Forgotten resources (especially public IPs and open VMs) expand the attack surface. |
| **Compliance** | Untagged resources violate internal governance policies and make cost allocation impossible. |
| **Accountability** | Without ownership tags, there is no way to attribute cost or responsibility. |

### 1.3 Proposed Solution

**InfraReaper** is a Cloud Resource Lifecycle & Cost Manager that automates the process of:

1. **Scanning** — Discovering all resources across targeted Azure subscriptions and resource groups.
2. **Evaluating** — Checking each resource against defined tag policies (required tags, valid values, expiry dates).
3. **Notifying** — Alerting resource owners and platform teams about policy violations and upcoming expirations.
4. **Cleaning Up** — Safely deallocating or deleting resources that have passed their expiry date, with safety checks and audit trails.
5. **Reporting** — Providing real-time dashboards showing resource inventory, cost attribution, compliance scores, and SLO tracking.

InfraReaper runs as a **Kubernetes CronJob on AKS**, executes every 30 minutes, and pushes metrics to Prometheus for Grafana dashboards.

---

## 2. Target Users

| User Role | How They Use InfraReaper |
|---|---|
| **Platform Engineers** | Deploy and operate InfraReaper. Configure policies. Monitor scanner health and SLOs. Respond to cleanup failures. |
| **DevOps Engineers** | Review compliance dashboards. Investigate cost attribution. Maintain CI/CD pipeline for InfraReaper itself. |
| **Development Team Leads** | Receive notifications about their team's resource violations. Use dashboards to track team compliance. |
| **Engineering Managers** | View cost attribution dashboards to understand spend by team/owner. Track compliance trends over time. |
| **Individual Engineers** | Receive email notifications when their resources are untagged, expiring, or have been cleaned up. Tag their resources correctly to avoid automated cleanup. |

---

## 3. Functional Requirements

### 3.1 Resource Scanning

| ID | Requirement | Priority |
|---|---|---|
| FR-SCAN-01 | The system SHALL scan all resources within configured Azure resource groups. | Must Have |
| FR-SCAN-02 | The system SHALL run scans on a configurable schedule (default: every 30 minutes). | Must Have |
| FR-SCAN-03 | The system SHALL authenticate to Azure using a Service Principal with the Reader role. | Must Have |
| FR-SCAN-04 | The system SHALL collect resource metadata: name, type, resource group, location, tags, provisioning state. | Must Have |
| FR-SCAN-05 | The system SHALL identify orphaned resources (unattached disks, unused public IPs). | Should Have |
| FR-SCAN-06 | The system SHALL log all scan activity with timestamps and resource counts. | Must Have |
| FR-SCAN-07 | The system SHALL complete a full scan within 5 minutes for up to 100 resources. | Should Have |

### 3.2 Policy Evaluation

| ID | Requirement | Priority |
|---|---|---|
| FR-POL-01 | The system SHALL evaluate resources against configurable tag policies defined in YAML. | Must Have |
| FR-POL-02 | The system SHALL check for required tags: `owner`, `environment`, `expiry-date`. | Must Have |
| FR-POL-03 | The system SHALL validate tag values against allowed values (e.g., environment must be one of: dev, staging, prod, test). | Should Have |
| FR-POL-04 | The system SHALL calculate a compliance score: `(compliant resources / total resources) × 100`. | Must Have |
| FR-POL-05 | The system SHALL categorize violations by severity: CRITICAL (no owner), WARNING (no expiry), INFO (invalid value). | Should Have |

### 3.3 Expiry & Lifecycle Management

| ID | Requirement | Priority |
|---|---|---|
| FR-EXP-01 | The system SHALL parse `expiry-date` tags (format: `YYYY-MM-DD`) to determine resource TTL. | Must Have |
| FR-EXP-02 | The system SHALL identify resources expiring within 24 hours, 72 hours, and 7 days. | Must Have |
| FR-EXP-03 | The system SHALL apply default TTL (30 days) to resources without an `expiry-date` tag, based on creation date. | Should Have |
| FR-EXP-04 | The system SHALL support grace periods (configurable, default: 48 hours after expiry) before cleanup. | Must Have |

### 3.4 Notifications

| ID | Requirement | Priority |
|---|---|---|
| FR-NOT-01 | The system SHALL send email notifications via SendGrid API for policy violations. | Must Have |
| FR-NOT-02 | The system SHALL send expiry warning emails at 7-day, 72-hour, and 24-hour thresholds. | Should Have |
| FR-NOT-03 | The system SHALL send cleanup confirmation emails after resources are deleted. | Must Have |
| FR-NOT-04 | The system SHALL include resource details in notifications: name, type, resource group, owner, violation type. | Must Have |
| FR-NOT-05 | The system SHALL support configurable notification recipients (per-resource via owner tag, plus a default recipient list). | Should Have |
| FR-NOT-06 | The system SHALL rate-limit notifications to prevent email flooding (max 1 notification per resource per 24 hours). | Should Have |

### 3.5 Cleanup

| ID | Requirement | Priority |
|---|---|---|
| FR-CLN-01 | The system SHALL safely delete or deallocate expired resources after the grace period. | Must Have |
| FR-CLN-02 | The system SHALL check a protected resources list before any deletion — protected resources are NEVER deleted. | Must Have |
| FR-CLN-03 | The system SHALL use a separate Service Principal with Contributor role (scoped to test resource group only) for cleanup operations. | Must Have |
| FR-CLN-04 | The system SHALL log every cleanup action with: resource ID, resource type, action taken, timestamp, result. | Must Have |
| FR-CLN-05 | The system SHALL support a dry-run mode that logs what WOULD be deleted without actually deleting. | Must Have |
| FR-CLN-06 | The system SHALL deallocate VMs before deleting them (graceful shutdown). | Should Have |
| FR-CLN-07 | The system SHALL NOT delete resources that have active locks (ReadOnly or CanNotDelete). | Must Have |

### 3.6 Metrics & Monitoring

| ID | Requirement | Priority |
|---|---|---|
| FR-MET-01 | The system SHALL push scan metrics to Prometheus Pushgateway after each scan. | Must Have |
| FR-MET-02 | Metrics SHALL include: total resources scanned, compliant count, non-compliant count, expired count, cleaned up count, scan duration, scan result (success/failure). | Must Have |
| FR-MET-03 | The system SHALL expose metrics for SLO calculation: `infrareaper_scan_success_total` and `infrareaper_scan_total`. | Must Have |
| FR-MET-04 | Grafana dashboards SHALL display: resource inventory, cost attribution, policy compliance, lifecycle timeline, scanner health, and SLO/error budget. | Must Have |

---

## 4. Non-Functional Requirements

### 4.1 Reliability

| ID | Requirement |
|---|---|
| NFR-REL-01 | The scanner SHALL achieve a 99% success rate (SLO) over a rolling 30-day window. This allows approximately 7 failed scans out of ~720 monthly executions (scans run every 30 minutes × 24 hours × 30 days). |
| NFR-REL-02 | A failed scan SHALL NOT affect subsequent scans — each scan execution is independent. |
| NFR-REL-03 | If the Pushgateway is unavailable, the scanner SHALL still complete the scan and log results locally. Metric push failure SHALL be logged but SHALL NOT cause the scan to fail. |
| NFR-REL-04 | If SendGrid is unavailable, notifications SHALL be logged but the scan SHALL NOT fail. |

### 4.2 Security

| ID | Requirement |
|---|---|
| NFR-SEC-01 | All credentials (Service Principal secrets, SendGrid API key) SHALL be stored in Azure Key Vault, NEVER in code, environment variables at rest, or Kubernetes manifests. |
| NFR-SEC-02 | The scanner Service Principal SHALL have the minimum required permissions: Reader role on subscription scope. |
| NFR-SEC-03 | The cleanup Service Principal SHALL be scoped to Contributor on the test resource group ONLY — never at subscription level. |
| NFR-SEC-04 | Kubernetes network policies SHALL restrict scanner pod communication to only Pushgateway and required Azure endpoints. |
| NFR-SEC-05 | The container image SHALL be scanned for vulnerabilities (Trivy) before being pushed to ACR. Builds SHALL fail on CRITICAL or HIGH severity vulnerabilities. |
| NFR-SEC-06 | Grafana SHALL be accessible via Entra ID SSO (OAuth2/OIDC) — no shared local passwords. |

### 4.3 Performance

| ID | Requirement |
|---|---|
| NFR-PERF-01 | A full scan of up to 100 resources SHALL complete within 5 minutes. |
| NFR-PERF-02 | The scanner SHALL minimize Azure API calls by batching resource listing operations. |
| NFR-PERF-03 | The CronJob Pod SHALL request no more than 256Mi memory and 250m CPU. |

### 4.4 Operability

| ID | Requirement |
|---|---|
| NFR-OPS-01 | The scanner SHALL produce structured log output (timestamped, leveled: INFO, WARN, ERROR) for consumption by Loki/Promtail. |
| NFR-OPS-02 | The system SHALL include a runbook documenting common failure scenarios and resolution steps. |
| NFR-OPS-03 | All infrastructure SHALL be reproducible from code — no manual Azure Portal changes in production. |
| NFR-OPS-04 | Alerts SHALL fire when: scanner hasn't run in 2 hours (CRITICAL), compliance drops below 70% (WARNING), error budget has ≤ 2 remaining failures (WARNING), cleanup action fails (CRITICAL). |

### 4.5 Cost

| ID | Requirement |
|---|---|
| NFR-COST-01 | Total Azure spend for the project SHALL remain under \$80. |
| NFR-COST-02 | Automated budget alerts SHALL trigger at \$10, \$25, \$50, and \$75 thresholds. |
| NFR-COST-03 | AKS SHALL use the free control plane tier with a single B2s node. |
| NFR-COST-04 | Test VMs SHALL be deallocated at end of each work session to avoid unnecessary charges. |

---

## 5. Constraints

| # | Constraint | Rationale |
|---|---|---|
| C-01 | Azure is the primary (and initially only) cloud provider. | Budget and learning focus. AWS is deferred. |
| C-02 | Total Azure budget is approximately \$100 in credits. Target spend: \$60–\$80. | Student credits / limited budget. |
| C-03 | AKS uses the free control plane tier with 1× Standard_B2s node. | Cost constraint — free tier sufficient for this workload. |
| C-04 | Scanner is implemented in Bash (using `az cli` + `jq`), not Python or Go. | Portfolio demonstrates Bash scripting + CLI mastery relevant to DevOps roles. Keeps the focus on infrastructure, not application development. |
| C-05 | CI/CD platform is Azure DevOps (free tier, limited to 1 parallel job with approval). | Demonstrates enterprise-relevant tooling. Free tier has a 1-job parallelism limit (requires Microsoft approval for free self-hosted agent grants). |
| C-06 | Self-hosted agent runs on a single lab server (Ubuntu 24.04, 4 CPU, 32 GB RAM). | No cloud-hosted agent costs. Demonstrates Linux server management. |
| C-07 | Email notifications use SendGrid free tier (100 emails/day). | No cost. Sufficient for project scale. |
| C-08 | All infrastructure must be defined as code (Terraform, Ansible, K8s manifests). | Core project requirement — IaC is a primary skill demonstration. |
| C-09 | The project is a single-person effort with AI assistance for application code. | Portfolio project, not a team effort. AI usage is documented transparently. |
| C-10 | Grafana SSO requires an Entra ID tenant where the user has admin rights (or at least Application Administrator). | Required to register OAuth2 applications for SSO. |

---

## 6. Out of Scope

The following items are deliberately excluded from this project. They are documented here to show intentional scope management.

| # | Item | Reason |
|---|---|---|
| OOS-01 | Multi-cloud scanning (AWS, GCP) | Deferred. Architecture supports future extension via `aws-scan.sh`, but implementation is not part of the initial release. |
| OOS-02 | Web UI or API for InfraReaper | The scanner is headless — all interaction is through dashboards (Grafana), email notifications, and CLI. No custom web frontend. |
| OOS-03 | Automatic tag remediation (auto-adding missing tags) | InfraReaper reports violations but does not auto-fix tags. This avoids overwriting intentional configurations. |
| OOS-04 | Real-time scanning (event-driven via Azure Event Grid) | Scans are scheduled (CronJob), not event-driven. Event-driven scanning adds complexity without proportional value at this scale. |
| OOS-05 | Multi-tenant / multi-subscription support | The scanner targets a single subscription. Multi-subscription support would require additional identity configuration. |
| OOS-06 | Cost optimization recommendations (rightsizing, reserved instances) | InfraReaper focuses on lifecycle and compliance, not workload optimization. Azure Advisor already handles rightsizing. |
| OOS-07 | Slack/Teams/PagerDuty integrations | Email (SendGrid) is the only notification channel. Additional channels can be added later. |
| OOS-08 | Database or persistent storage for scan history | Scan results are ephemeral — they exist as metrics in Prometheus (retention-limited) and logs in Loki. There is no database. |
| OOS-09 | Terraform state management for the scanner itself | The scanner runs as scripts, not Terraform-managed infrastructure. Terraform manages the infrastructure the scanner runs ON. |
| OOS-10 | Production-grade high availability (multi-node AKS, replicas) | Single-node AKS is sufficient for this portfolio project. HA design is documented in architecture as a future improvement. |

---

## 7. Success Criteria

The project is considered complete when ALL of the following are true:

| # | Criterion | How to Verify |
|---|---|---|
| SC-01 | InfraReaper scanner runs as a CronJob on AKS every 30 minutes. | `kubectl get cronjobs -n infrareaper` shows schedule and last successful run. |
| SC-02 | Scanner correctly identifies untagged, mistagged, and expired test resources. | Review scan logs in Loki; compare against known test resource states. |
| SC-03 | Email notifications are sent for policy violations and expiry warnings. | Check SendGrid activity log; verify email received. |
| SC-04 | Expired resources are safely cleaned up after grace period. | Test resource is deleted; audit log confirms action; protected resources are untouched. |
| SC-05 | All 6 Grafana dashboards display accurate, real-time data. | Visual inspection of dashboards during and after scan. |
| SC-06 | SLO dashboard shows correct error budget calculation (99% target). | Simulate failures; verify error budget decrements correctly. |
| SC-07 | CI/CD pipeline (Azure DevOps) validates, builds, scans, and deploys on merge to main. | Trigger pipeline via PR merge; all stages pass. |
| SC-08 | All infrastructure is provisioned via Terraform (no portal-created resources in prod). | `terraform plan` shows no drift. |
| SC-09 | Lab server is configured via Ansible (repeatable). | Run playbook on a fresh server; agent registers with Azure DevOps. |
| SC-10 | At least 3 failure scenarios have been tested and documented with resolution. | Failure scenarios doc with screenshots and resolution steps. |
| SC-11 | Total Azure spend is under \$80. | Azure Cost Management confirms. |
| SC-12 | Professional documentation is complete (architecture, runbook, security model, cost analysis). | All docs listed in repo structure exist and are substantive. |

---

## 8. Glossary

| Term | Definition |
|---|---|
| **TTL** | Time To Live — the duration a resource is allowed to exist before it must be renewed or deleted. |
| **CronJob** | A Kubernetes resource that runs a containerized task on a schedule (similar to Linux cron). |
| **Tag** | A key-value pair attached to an Azure resource for identification, cost tracking, and policy enforcement. |
| **Service Principal (SP)** | An identity in Entra ID used by applications and automation to authenticate to Azure. |
| **RBAC** | Role-Based Access Control — assigning permissions to identities based on roles (Reader, Contributor, Owner). |
| **SLO** | Service Level Objective — a target reliability level (e.g., 99% successful scans). |
| **SLI** | Service Level Indicator — the metric that measures the SLO (e.g., successful scans / total scans). |
| **Error Budget** | The allowed number of failures before the SLO is breached. At 99% SLO with 720 monthly scans, the error budget is ~7 failures. |
| **Pushgateway** | A Prometheus component that accepts metrics from short-lived jobs (like CronJobs) that can't be scraped directly. |
| **ACR** | Azure Container Registry — a managed Docker registry for storing container images. |
| **AKS** | Azure Kubernetes Service — a managed Kubernetes cluster in Azure. |
| **IaC** | Infrastructure as Code — managing infrastructure through version-controlled definition files. |
| **Orphaned Resource** | A resource that exists but is not attached or in use (e.g., an unattached managed disk or a public IP with no NIC). |
| **Grace Period** | A buffer time after resource expiry before cleanup is executed, allowing owners to renew if needed. |
| **Dry-Run Mode** | A mode where the scanner logs what actions WOULD be taken without actually performing them. |

---

## Revision History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-10-04 | Santhosh | Initial requirements document — Phase 1. |
