terraform {
  required_version = "~> 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.24"
    }
  }
}

data "azurerm_virtual_network" "existing" {
  count               = var.use_existing_virtual_network ? 1 : 0
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "existing" {
  count                = var.use_existing_virtual_network ? 1 : 0
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

resource "azurerm_virtual_network" "this" {
  count               = var.use_existing_virtual_network ? 0 : 1
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  dns_servers         = length(var.custom_dns_servers) > 0 ? var.custom_dns_servers : null
  tags                = var.tags
}

resource "azurerm_network_security_group" "this" {
  count               = var.use_existing_virtual_network ? 0 : 1
  name                = "${var.subnet_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  count                = var.use_existing_virtual_network ? 0 : 1
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = var.subnet_address_prefixes
}

resource "azurerm_subnet_network_security_group_association" "this" {
  count                     = var.use_existing_virtual_network ? 0 : 1
  subnet_id                 = azurerm_subnet.this[0].id
  network_security_group_id = azurerm_network_security_group.this[0].id
}

resource "azurerm_public_ip" "nat" {
  count               = var.enable_public_outbound && !var.use_existing_virtual_network ? 1 : 0
  name                = "${var.vnet_name}-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "this" {
  count               = var.enable_public_outbound && !var.use_existing_virtual_network ? 1 : 0
  name                = "${var.vnet_name}-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count                = var.enable_public_outbound && !var.use_existing_virtual_network ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  count          = var.enable_public_outbound && !var.use_existing_virtual_network ? 1 : 0
  subnet_id      = azurerm_subnet.this[0].id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
