output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "host_pool_name" {
  value = module.hostpool.host_pool_name
}

output "workspace_name" {
  value = module.workspace.workspace_name
}

output "sessionhost_vm_name" {
  value = module.sessionhost.vm_name
}

output "sessionhost_private_ip" {
  value = module.sessionhost.private_ip_address
}

output "sessionhost_aad_login_extension_id" {
  value = module.sessionhost.aad_login_extension_id
}

output "dbserver_vm_name" {
  value = module.dbserver.vm_name
}

output "dbserver_private_ip" {
  value = module.dbserver.private_ip_address
}

output "dbserver_data_disk_id" {
  value = module.dbserver.data_disk_id
}

output "dbserver_aad_login_extension_id" {
  value = module.dbserver.aad_login_extension_id
}

output "vm_login_role_assignment_ids" {
  value = {
    for key, assignment in azurerm_role_assignment.vm_login :
    key => assignment.id
  }
}
