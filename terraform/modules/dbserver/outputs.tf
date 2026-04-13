output "vm_name" {
  value = azurerm_windows_virtual_machine.this.name
}

output "private_ip_address" {
  value = azurerm_network_interface.this.private_ip_address
}

output "data_disk_id" {
  value = try(azurerm_managed_disk.data[0].id, null)
}

output "aad_login_extension_id" {
  value = try(azurerm_virtual_machine_extension.aad_login[0].id, null)
}

output "vm_resource_id" {
  value = azurerm_windows_virtual_machine.this.id
}
