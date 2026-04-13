terraform {
  required_version = "~> 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.24"
    }
  }
}

resource "azurerm_virtual_desktop_application_group" "this" {
  name                = var.app_group_name
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "RemoteApp"
  friendly_name       = var.app_group_friendly_name
  host_pool_id        = var.host_pool_id
  tags                = var.tags
}

resource "azurerm_virtual_desktop_application" "rdpwin" {
  name                         = var.remote_application_name
  application_group_id         = azurerm_virtual_desktop_application_group.this.id
  friendly_name                = var.remote_application_friendly_name
  path                         = var.remote_application_path
  command_line_argument_policy = "DoNotAllow"
  show_in_portal               = true
}
