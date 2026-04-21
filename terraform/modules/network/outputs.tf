output "subnet_id" {
  value = var.use_existing_virtual_network ? data.azurerm_subnet.existing[0].id : azurerm_subnet.this[0].id
}
