variable "project_name" {
  type = string
}

variable "location" {
  type = string
}

variable "environment_name" {
  type = string
}

variable "group" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "use_existing_resource_group" {
  type    = bool
  default = false
}

variable "vnet_name" {
  type = string
}

variable "use_existing_virtual_network" {
  type    = bool
  default = false
}

variable "subnet_name" {
  type = string
}

variable "workspace_name" {
  type = string
}

variable "host_pool_name" {
  type = string
}

variable "app_group_name" {
  type = string
}

variable "desktop_app_group_name" {
  type = string
}

variable "sessionhost_vm_name" {
  type = string
}

variable "sessionhost_computer_name" {
  type = string
}

variable "sessionhost_vm_size" {
  type = string
}

variable "sessionhost_admin_username" {
  type = string
}

variable "sessionhost_admin_password" {
  type      = string
  sensitive = true
}

variable "sessionhost_image_publisher" {
  type = string
}

variable "sessionhost_image_offer" {
  type = string
}

variable "sessionhost_image_sku" {
  type = string
}

variable "sessionhost_image_version" {
  type = string
}

variable "dbserver_vm_name" {
  type = string
}

variable "dbserver_computer_name" {
  type = string
}

variable "dbserver_vm_size" {
  type = string
}

variable "dbserver_admin_username" {
  type = string
}

variable "dbserver_admin_password" {
  type      = string
  sensitive = true
}

variable "dbserver_image_publisher" {
  type = string
}

variable "dbserver_image_offer" {
  type = string
}

variable "dbserver_image_sku" {
  type = string
}

variable "dbserver_image_version" {
  type = string
}

variable "dbserver_enable_aad_login_extension" {
  type    = bool
  default = true
}

variable "dbserver_create_data_disk" {
  type    = bool
  default = true
}

variable "dbserver_data_disk_size_gb" {
  type    = number
  default = 256
}

variable "dbserver_data_disk_storage_account_type" {
  type    = string
  default = "StandardSSD_LRS"
}

variable "vnet_address_space" {
  type = list(string)
}

variable "subnet_address_prefixes" {
  type = list(string)
}

variable "custom_dns_servers" {
  type    = list(string)
  default = []
}

variable "host_pool_friendly_name" {
  type = string
}

variable "workspace_friendly_name" {
  type = string
}

variable "app_group_friendly_name" {
  type = string
}

variable "desktop_app_group_friendly_name" {
  type = string
}

variable "remote_application_name" {
  type = string
}

variable "remote_application_friendly_name" {
  type = string
}

variable "remote_application_path" {
  type = string
}

variable "enable_public_outbound" {
  type    = bool
  default = true
}

variable "enable_aad_login_extension" {
  type    = bool
  default = true
}

variable "vm_user_login_principal_ids" {
  type    = list(string)
  default = []
}

variable "vm_admin_login_principal_ids" {
  type    = list(string)
  default = []
}

variable "avd_user_principal_ids" {
  type    = list(string)
  default = []
}

variable "avd_desktop_user_principal_ids" {
  type    = list(string)
  default = []
}

variable "avd_remoteapp_user_principal_ids" {
  type    = list(string)
  default = []
}

variable "enable_desktop_app_group" {
  type    = bool
  default = true
}

variable "additional_tags" {
  type    = map(string)
  default = {}
}
