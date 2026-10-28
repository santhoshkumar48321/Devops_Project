# InfraReaper — Operations & Troubleshooting Runbook

This runbook covers day-to-day operations, emergency procedures, troubleshooting steps, and maintenance routines for InfraReaper.

---

## 🏃 Common Operations

### 1. Trigger an Immediate Manual Scan Job
To execute a scan immediately outside the scheduled 30-minute CronJob window:
```bash
JOB_NAME="manual-scan-$(date +%s)"
kubectl create job --from=cronjob/infrareaper-scanner "${JOB_NAME}" -n infrareaper
kubectl logs -n infrareaper -l job-name="${JOB_NAME}" -f
```

### 2. View Real-Time Scanner Logs
Stream logs from the latest scanner execution:
```bash
kubectl logs -n infrareaper -l app=infrareaper-scanner --tail=100 -f
```
Or view historical logs directly in Grafana via Loki:
```logql
{namespace="infrareaper"} |= "ERROR"
```

### 3. Access Monitoring Dashboards
- **Direct Forward (from lab machine)**:
  ```bash
  kubectl port-forward svc/grafana 3000:3000 -n infrareaper --address 0.0.0.0
  ```
- **SSH Tunnel (from Windows laptop to Hyper-V VM)**:
  ```cmd
  ssh -L 3000:localhost:3000 santhosh@<LAB_VM_IP>
  ```
  Open `http://localhost:3000` in your browser.

---

## ⚙️ Configuration & Policy Changes

### 1. Toggle Dry-Run Mode to Real Enforcement
By default, the `dev` overlay runs with `DRY_RUN=true` (simulates deletions safely).

To enable real resource cleanup in production:
1. Edit `kubernetes/overlays/prod/cronjob-patch.yaml`:
   ```yaml
   - name: DRY_RUN
     value: "false"
   ```
2. Deploy the prod overlay:
   ```bash
   make deploy-prod
   ```

### 2. Protect Specific Resources from Purge
To prevent a critical test asset or storage account from ever being cleaned up:
1. Edit `policies/protected-resources.yaml`.
2. Add the resource under `protected_resources`:
   ```yaml
   protected_resources:
     - id: "/subscriptions/<SUB_ID>/resourceGroups/my-rg/providers/Microsoft.Storage/storageAccounts/criticalstore"
       reason: "Long-term test data archive"
   ```
3. Commit and push. The pipeline will automatically redeploy the updated policy ConfigMap.

---

## 🔧 Troubleshooting Guide

### Issue 1: Scanner Pod Fails with "Not authenticated to Azure"
- **Cause**: Kubernetes secret `infrareaper-secrets` is missing or contains placeholder values.
- **Resolution**:
  Re-synchronize live credentials from Azure Key Vault:
  ```bash
  SP_CLIENT_ID=$(az keyvault secret show --vault-name infrareaperkv-k9r9y --name AZURE-CLIENT-ID --query value -o tsv)
  SP_SECRET=$(az keyvault secret show --vault-name infrareaperkv-k9r9y --name AZURE-CLIENT-SECRET --query value -o tsv)
  SP_TENANT=$(az keyvault secret show --vault-name infrareaperkv-k9r9y --name AZURE-TENANT-ID --query value -o tsv)

  kubectl create secret generic infrareaper-secrets -n infrareaper \
    --from-literal=AZURE_CLIENT_ID="${SP_CLIENT_ID}" \
    --from-literal=AZURE_CLIENT_SECRET="${SP_SECRET}" \
    --from-literal=AZURE_TENANT_ID="${SP_TENANT}" \
    --dry-run=client -o yaml | kubectl apply -f -
  ```

### Issue 2: Pushgateway Reports "HTTP 000" or "Unreachable"
- **Cause**: `prometheus-pushgateway` pod is not running or network policy is blocking traffic.
- **Resolution**:
  1. Check Pushgateway pod status:
     ```bash
     kubectl get pods -n infrareaper -l app.kubernetes.io/name=prometheus-pushgateway
     ```
  2. Verify NetworkPolicy allows port 9091 egress from scanner pods:
     ```bash
     kubectl describe networkpolicy infrareaper-scanner-netpol -n infrareaper
     ```

### Issue 3: Lab Server Disk Space Exceeded (>95%)
- **Cause**: Docker builder cache or system journal accumulation.
- **Resolution**:
  Execute safe disk cleanup on the lab machine:
  ```bash
  docker system prune -af --volumes
  sudo apt-get clean
  sudo journalctl --vacuum-time=1d
  df -h /
  ```

---

## 💰 Cost Safeguards & Budget Optimization

- To stay within the Azure Student budget, test VMs can be deallocated when not actively in use:
  ```bash
  az vm deallocate --resource-group infrareaper-test-resources --name test-vm-tagged
  az vm deallocate --resource-group infrareaper-test-resources --name test-vm-untagged
  ```
- Core AKS nodes run on `sku_tier = "Free"` control plane tier with single-node auto-scaling.
