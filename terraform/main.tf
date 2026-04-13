resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

module "network" {
  source                  = "./modules/network"
  resource_group_name     = azurerm_resource_group.lab.name
  location                = var.location
  vnet_name               = var.vnet_name
  vnet_address_space      = var.vnet_address_space
  subnet_name             = var.subnet_name
  subnet_address_prefixes = var.subnet_address_prefixes
  custom_dns_servers      = var.custom_dns_servers
  enable_public_outbound  = var.enable_public_outbound
  tags                    = local.tags
}

module "hostpool" {
  source              = "./modules/hostpool"
  resource_group_name = azurerm_resource_group.lab.name
  location            = var.location
  host_pool_name      = var.host_pool_name
  friendly_name       = var.host_pool_friendly_name
  tags                = local.tags
}

module "appgroup" {
  source                           = "./modules/appgroup"
  resource_group_name              = azurerm_resource_group.lab.name
  location                         = var.location
  host_pool_id                     = module.hostpool.host_pool_id
  app_group_name                   = var.app_group_name
  app_group_friendly_name          = var.app_group_friendly_name
  remote_application_name          = var.remote_application_name
  remote_application_friendly_name = var.remote_application_friendly_name
  remote_application_path          = var.remote_application_path
  tags                             = local.tags
}

module "workspace" {
  source              = "./modules/workspace"
  resource_group_name = azurerm_resource_group.lab.name
  location            = var.location
  workspace_name      = var.workspace_name
  friendly_name       = var.workspace_friendly_name
  app_group_id        = module.appgroup.app_group_id
  tags                = local.tags
}

module "sessionhost" {
  source                     = "./modules/sessionhost"
  resource_group_name        = azurerm_resource_group.lab.name
  location                   = var.location
  subnet_id                  = module.network.subnet_id
  vm_name                    = var.sessionhost_vm_name
  computer_name              = var.sessionhost_computer_name
  vm_size                    = var.sessionhost_vm_size
  admin_username             = var.sessionhost_admin_username
  admin_password             = var.sessionhost_admin_password
  image_publisher            = var.sessionhost_image_publisher
  image_offer                = var.sessionhost_image_offer
  image_sku                  = var.sessionhost_image_sku
  image_version              = var.sessionhost_image_version
  registration_token         = module.hostpool.registration_token
  enable_aad_login_extension = var.enable_aad_login_extension
  tags                       = local.tags
}

module "dbserver" {
  source                         = "./modules/dbserver"
  resource_group_name            = azurerm_resource_group.lab.name
  location                       = var.location
  subnet_id                      = module.network.subnet_id
  vm_name                        = var.dbserver_vm_name
  computer_name                  = var.dbserver_computer_name
  vm_size                        = var.dbserver_vm_size
  admin_username                 = var.dbserver_admin_username
  admin_password                 = var.dbserver_admin_password
  image_publisher                = var.dbserver_image_publisher
  image_offer                    = var.dbserver_image_offer
  image_sku                      = var.dbserver_image_sku
  image_version                  = var.dbserver_image_version
  enable_aad_login_extension     = var.dbserver_enable_aad_login_extension
  create_data_disk               = var.dbserver_create_data_disk
  data_disk_size_gb              = var.dbserver_data_disk_size_gb
  data_disk_storage_account_type = var.dbserver_data_disk_storage_account_type
  tags                           = local.tags
}

resource "azurerm_role_assignment" "vm_login" {
  for_each = local.vm_login_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role_name
  principal_id         = each.value.principal_id
}
