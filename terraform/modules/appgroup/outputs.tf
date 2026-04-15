output "remoteapp_group_id" {
  value = azurerm_virtual_desktop_application_group.remoteapp.id
}

output "desktop_group_id" {
  value = try(azurerm_virtual_desktop_application_group.desktop[0].id, null)
}
