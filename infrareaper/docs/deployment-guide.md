# InfraReaper — Deployment & Setup Guide

This guide provides step-by-step instructions for deploying the complete InfraReaper ecosystem, from bare-metal lab provisioning to cloud infrastructure and Kubernetes monitoring.

---

## 📋 Prerequisites & Tools

- **Local / Lab Machine**: Ubuntu 24.04 (or Hyper-V VM / WSL2).
- **Azure Account**: Active subscription with Contributor and User Access Administrator permissions.
- **Tools Required**:
  - `az cli` (v2.64+)
  - `terraform` (v1.12+)
  - `ansible` (v2.17+)
  - `kubectl` (v1.30+)
  - `docker` (v27+)
  - `trivy` (v0.62+)
  - `jq`, `curl`, `make`

---

## 🛠️ Step 1: Provision Lab Server via Ansible (Phase 4)

1. Clone the repository:
   ```bash
   git clone https://github.com/santhoshkumar48321/Devops_Project.git
   cd Devops_Project/infrareaper
   ```

2. Configure Ansible inventory in `ansible/inventory/hosts.yml`.

3. Execute the server setup playbook:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/setup-lab-server.yml \
     --tags common,docker,security
   ```

4. Register the Azure DevOps self-hosted agent:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/setup-lab-server.yml \
     --tags agent \
     -e "azdo_org_url=https://dev.azure.com/<YOUR_ORG>" \
     -e "azdo_pat_token=<YOUR_PAT_TOKEN>"
   ```

---

## ☁️ Step 2: Provision Cloud Infrastructure with Terraform (Phase 5)

1. Log in to Azure:
   ```bash
   az login
   az account set --subscription "<SUBSCRIPTION_ID>"
   ```

2. Initialize remote state backend:
   ```bash
   bash scripts/bootstrap-state-backend.sh
   ```

3. Deploy core cloud resources (VNet, AKS, ACR, Key Vault, Test targets):
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

4. Verify deployed resources:
   ```bash
   az resource list --resource-group infrareaper-core-rg -o table
   az resource list --resource-group infrareaper-test-resources -o table
   ```

---

## 🐳 Step 3: Container Build & Vulnerability Scan (Phase 7)

1. Authenticate Docker with Azure Container Registry:
   ```bash
   az acr login --name infrareaperacrpalwa
   ```

2. Build and scan the hardened container image:
   ```bash
   make build
   make scan-image
   make push
   ```

---

## ☸️ Step 4: Deploy Kubernetes Engine to AKS (Phase 8)

1. Connect `kubectl` to AKS:
   ```bash
   az aks get-credentials --resource-group infrareaper-core-rg --name infrareaper-aks --overwrite-existing
   ```

2. Deploy the Dev overlay via Kustomize:
   ```bash
   make deploy
   ```

3. Synchronize Service Principal credentials from Key Vault into Kubernetes secrets:
   ```bash
   SP_CLIENT_ID=$(az keyvault secret show --vault-name infrareaperkv-k9r9y --name AZURE-CLIENT-ID --query value -o tsv)
   SP_SECRET=$(az keyvault secret show --vault-name infrareaperkv-k9r9y --name AZURE-CLIENT-SECRET --query value -o tsv)
   SP_TENANT=$(az keyvault secret show --vault-name infrareaperkv-k9r9y --name AZURE-TENANT-ID --query value -o tsv)

   kubectl create secret generic infrareaper-secrets -n infrareaper \
     --from-literal=AZURE_CLIENT_ID="${SP_CLIENT_ID}" \
     --from-literal=AZURE_CLIENT_SECRET="${SP_SECRET}" \
     --from-literal=AZURE_TENANT_ID="${SP_TENANT}" \
     --from-literal=CLEANUP_CLIENT_ID="${SP_CLIENT_ID}" \
     --from-literal=CLEANUP_CLIENT_SECRET="${SP_SECRET}" \
     --from-literal=CLEANUP_TENANT_ID="${SP_TENANT}" \
     --from-literal=SENDGRID_API_KEY="" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

4. Trigger a manual execution test job:
   ```bash
   kubectl create job --from=cronjob/infrareaper-scanner test-run-01 -n infrareaper
   kubectl logs -n infrareaper -l job-name=test-run-01 -f
   ```

---

## 📈 Step 5: Deploy Observability Stack (Phase 10)

1. Deploy Prometheus, Pushgateway, Alertmanager, Loki, Promtail, and Grafana:
   ```bash
   make deploy-monitoring
   ```

2. Verify all pods are running:
   ```bash
   kubectl get pods -n infrareaper
   ```

3. Forward Grafana to your local workstation:
   ```bash
   make port-forward-grafana
   ```
   Open `http://localhost:3000` in your browser. All 6 dashboards are pre-loaded in the **InfraReaper** folder!

