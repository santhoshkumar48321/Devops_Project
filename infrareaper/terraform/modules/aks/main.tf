# ============================================================
# Module: aks — Main
# ============================================================
# Provisions a single-node AKS cluster with Free tier control
# plane, managed identity, and native ACR integration.
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0, < 5.0.0"
    }
  }
}

# ──────────────────────────────────────────────
# 1. Managed AKS Cluster
# ──────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix

  # Free control plane tier (0$ cost)
  sku_tier = "Free"

  default_node_pool {
    name            = "systempool"
    node_count      = var.node_count
    vm_size         = var.vm_size
    vnet_subnet_id  = var.system_subnet_id
    os_disk_size_gb = 30
    os_disk_type    = "Managed"

    tags = merge(
      {
        Project     = "InfraReaper"
        Component   = "AKS-NodePool"
        Environment = var.environment
      },
      var.tags
    )
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  tags = merge(
    {
      Project     = "InfraReaper"
      Component   = "AKS-Cluster"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ──────────────────────────────────────────────
# 2. Attach ACR to AKS (AcrPull Role)
# ──────────────────────────────────────────────
# Allows the AKS kubelet identity to pull scanner container images
# from ACR without needing docker login or imagePullSecrets!
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.attach_acr ? 1 : 0
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = var.acr_id
}

