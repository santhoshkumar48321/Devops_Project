# InfraReaper — Security & Threat Model

InfraReaper is built following strict defense-in-depth security principles to prevent accidental infrastructure damage, credential leakage, or unauthorized lateral movement.

---

## 🛡️ Defense-in-Depth Architecture

```
Layer 1: Identity & RBAC          → Scoped Service Principal (Restricted Contributor)
Layer 2: Secrets Management       → Azure Key Vault (Zero plaintext secrets)
Layer 3: Network Security         → Kubernetes NetworkPolicy (Zero Ingress, Restricted Egress)
Layer 4: Container Hardening      → Non-root UID 10001, ReadOnlyRootFilesystem, Drop ALL Caps
Layer 5: IaC & Image Auditing     → Automated Trivy Vulnerability & Misconfiguration Scans
Layer 6: Operational Safeguards   → Protected Resource Lists, Dry-Run Simulation, 48h Grace Period
```

---

## 🔑 Identity & Access Management (IAM)

1. **Dedicated Service Principal**: The scanner uses an isolated Entra ID Service Principal (`infrareaper-scanner-sp`).
2. **Role-Based Access Control**:
   - Granted `Reader` across target subscriptions to discover resources.
   - Granted scoped `Contributor` ONLY on designated test resource groups (`infrareaper-test-resources`).
   - Explicitly blocked from core infrastructure (`infrareaper-core-rg`) and state backends (`infrareaper-state-rg`).
3. **Azure Key Vault Secrets Sync**:
   - Credentials (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`) are stored exclusively in Azure Key Vault.
   - Synchronized directly to Kubernetes Secrets in namespace `infrareaper` during pipeline deployment.

---

## 🔒 Container Security & CIS Hardening

- **Base Image**: Official Microsoft Azure CLI runtime (`mcr.microsoft.com/azure-cli`).
- **Unprivileged User**: Runs as dedicated system user `infrareaper` (`UID: 10001`, `GID: 10001`).
- **Read-Only Root Filesystem**:
  ```yaml
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
  ```
- **Storage Isolation**: Temporary runtime files, reports, and Azure CLI caches write strictly to ephemeral `emptyDir` volumes mounted at `/tmp` and `/home/infrareaper/.azure`.

---

## 🌐 Network Security Policy

A strict Kubernetes `NetworkPolicy` (`infrareaper-scanner-netpol`) enforces network boundaries:

1. **Ingress**: **100% Denied** (The scanner pod exposes no listening TCP/UDP ports).
2. **Egress**:
   - Allowed: CoreDNS (`port 53 TCP/UDP`).
   - Allowed: Azure Resource Manager API & SendGrid API (`port 443 TCP` outbound to internet).
   - Allowed: Internal Prometheus Pushgateway (`port 9091 TCP`).
   - Denied: All other private and public traffic.

---

## 🔍 Vulnerability Management (Trivy Policy)

Every pull request and build undergoes automated Trivy vulnerability scanning:
- **Zero Critical & High CVEs**: New vulnerabilities fail the pipeline immediately (`--exit-code 1`).
- **Upstream CVE Tracking**: Documented base image vulnerabilities originating in Microsoft's upstream Python runtime are evaluated and tracked in `.trivyignore` with explicit architectural risk assessments.

