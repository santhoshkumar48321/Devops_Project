# ============================================================
# Module: test-resources — Main
# ============================================================
# Provisions a realistic sandbox environment with intentionally
# compliant, non-compliant, expired, and orphaned resources
# for InfraReaper to scan, detect, and clean up safely.
# When var.enable_test_vms is false, only the resource group
# and VNet are created for manual developer testing.
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

# ──────────────────────────────────────────────
# 1. Isolated Test Resource Group
# ──────────────────────────────────────────────
resource "azurerm_resource_group" "test_rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "sandbox"
    Purpose     = "InfraReaper-Target-Testing"
  }
}

# ──────────────────────────────────────────────
# 2. Test VNet & Subnet for Test VMs
# ──────────────────────────────────────────────
resource "azurerm_virtual_network" "test_vnet" {
  name                = "test-sandbox-vnet"
  resource_group_name = azurerm_resource_group.test_rg.name
  location            = azurerm_resource_group.test_rg.location
  address_space       = ["10.1.0.0/16"]

  tags = {
    owner       = "santhosh"
    environment = "dev"
    expiry-date = "2026-12-01"
  }
}

resource "azurerm_subnet" "test_subnet" {
  name                 = "test-sandbox-subnet"
  resource_group_name  = azurerm_resource_group.test_rg.name
  virtual_network_name = azurerm_virtual_network.test_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

# ──────────────────────────────────────────────
# 3. Target 1: Properly Tagged Compliant VM
# ──────────────────────────────────────────────
resource "azurerm_network_interface" "tagged_nic" {
  count               = var.enable_test_vms ? 1 : 0
  name                = "test-vm-tagged-nic"
  location            = azurerm_resource_group.test_rg.location
  resource_group_name = azurerm_resource_group.test_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    owner       = "santhosh"
    environment = "dev"
    expiry-date = "2026-12-01"
  }
}

resource "azurerm_linux_virtual_machine" "tagged_vm" {
  count                           = var.enable_test_vms ? 1 : 0
  name                            = "test-vm-tagged"
  resource_group_name             = azurerm_resource_group.test_rg.name
  location                        = azurerm_resource_group.test_rg.location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.tagged_nic[0].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # COMPLIANT TAGS
  tags = {
    owner       = "santhosh"
    environment = "dev"
    expiry-date = "2026-12-01"
  }
}

# ──────────────────────────────────────────────
# 4. Target 2: Untagged Non-Compliant VM (Violation)
# ──────────────────────────────────────────────
resource "azurerm_network_interface" "untagged_nic" {
  count               = var.enable_test_vms ? 1 : 0
  name                = "test-vm-untagged-nic"
  location            = azurerm_resource_group.test_rg.location
  resource_group_name = azurerm_resource_group.test_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {}
}

resource "azurerm_linux_virtual_machine" "untagged_vm" {
  count                           = var.enable_test_vms ? 1 : 0
  name                            = "test-vm-untagged"
  resource_group_name             = azurerm_resource_group.test_rg.name
  location                        = azurerm_resource_group.test_rg.location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.untagged_nic[0].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # NO TAGS (Deliberate policy violation for scanner to catch)
  tags = {}
}

# ──────────────────────────────────────────────
# 5. Target 3: Expired Storage Account (Cleanup target)
# ──────────────────────────────────────────────
resource "random_string" "storage_suffix" {
  count   = var.enable_test_vms ? 1 : 0
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "expired_sa" {
  count                    = var.enable_test_vms ? 1 : 0
  name                     = "testexpired${random_string.storage_suffix[0].result}"
  resource_group_name      = azurerm_resource_group.test_rg.name
  location                 = azurerm_resource_group.test_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # EXPIRED TAG (Date in the past for automated reaper cleanup testing)
  tags = {
    owner       = "santhosh"
    environment = "dev"
    expiry-date = "2026-01-01"
  }
}

# ──────────────────────────────────────────────
# 6. Target 4: Orphaned Public IP (Unused / No NIC)
# ──────────────────────────────────────────────
resource "azurerm_public_ip" "orphan_ip" {
  count               = var.enable_test_vms ? 1 : 0
  name                = "test-orphan-ip"
  resource_group_name = azurerm_resource_group.test_rg.name
  location            = azurerm_resource_group.test_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"

  # No tags and unattached
  tags = {}
}

# ──────────────────────────────────────────────
# 7. Target 5: Unattached Managed Disk
# ──────────────────────────────────────────────
resource "azurerm_managed_disk" "unattached_disk" {
  count                = var.enable_test_vms ? 1 : 0
  name                 = "test-unattached-disk"
  location             = azurerm_resource_group.test_rg.location
  resource_group_name  = azurerm_resource_group.test_rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32

  # No tags and unattached to any VM
  tags = {}
}
