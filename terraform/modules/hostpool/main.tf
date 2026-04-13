terraform {
  required_version = "~> 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.24"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

resource "azurerm_virtual_desktop_host_pool" "this" {
  name                     = var.host_pool_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = 16
  preferred_app_group_type = "RailApplications"
  friendly_name            = var.friendly_name
  start_vm_on_connect      = true
  custom_rdp_properties    = "redirectclipboard:i:1;redirectprinters:i:1;drivestoredirect:s:;devicestoredirect:s:;redirectwebauthn:i:1;use multimon:i:1;enablerdsaadauth:i:1;"
  tags                     = var.tags
}

resource "time_rotating" "registration" {
  rotation_days = 7
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "this" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.this.id
  expiration_date = timeadd(time_rotating.registration.rfc3339, "168h")
}
