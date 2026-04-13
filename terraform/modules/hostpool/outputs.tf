output "host_pool_id" {
  value = azurerm_virtual_desktop_host_pool.this.id
}

output "host_pool_name" {
  value = azurerm_virtual_desktop_host_pool.this.name
}

output "registration_token" {
  value     = azurerm_virtual_desktop_host_pool_registration_info.this.token
  sensitive = true
}
