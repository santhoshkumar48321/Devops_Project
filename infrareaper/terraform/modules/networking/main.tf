# ============================================================
# Module: networking — Main
# ============================================================
# Provisions the VNet, Subnet for AKS, and NSG security rules.
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
# 1. Virtual Network
# ──────────────────────────────────────────────
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  tags = merge(
    {
      Project     = "InfraReaper"
      Component   = "Networking"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ──────────────────────────────────────────────
# 2. AKS System Subnet
# ──────────────────────────────────────────────
resource "azurerm_subnet" "system_subnet" {
  name                 = var.system_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.system_subnet_prefixes
}

# ──────────────────────────────────────────────
# 3. Network Security Group (NSG)
# ──────────────────────────────────────────────
resource "azurerm_network_security_group" "aks_nsg" {
  name                = "${var.vnet_name}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow Outbound HTTPS (for ARM API, ACR image pulls, SendGrid email)
  security_rule {
    name                       = "AllowOutboundHTTPS"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Allow Outbound DNS
  security_rule {
    name                       = "AllowOutboundDNS"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow Inbound to Grafana (port 3000 / 80)
  security_rule {
    name                       = "AllowInboundGrafana"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "3000"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(
    {
      Project     = "InfraReaper"
      Component   = "Networking-NSG"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ──────────────────────────────────────────────
# 4. Associate NSG with AKS Subnet
# ──────────────────────────────────────────────
resource "azurerm_subnet_network_security_group_association" "system_assoc" {
  subnet_id                 = azurerm_subnet.system_subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

