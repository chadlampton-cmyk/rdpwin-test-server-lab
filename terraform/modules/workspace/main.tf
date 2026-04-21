terraform {
  required_version = "~> 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.24"
    }
  }
}

resource "azurerm_virtual_desktop_workspace" "this" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  friendly_name       = var.friendly_name
  tags                = var.tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "this" {
  for_each = var.app_group_ids_by_key

  workspace_id         = azurerm_virtual_desktop_workspace.this.id
  application_group_id = each.value
}
