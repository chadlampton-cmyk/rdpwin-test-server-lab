variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vnet_name" { type = string }
variable "vnet_address_space" { type = list(string) }
variable "subnet_name" { type = string }
variable "subnet_address_prefixes" { type = list(string) }
variable "custom_dns_servers" { type = list(string) }
variable "enable_public_outbound" { type = bool }
variable "use_existing_virtual_network" {
  type    = bool
  default = false
}
variable "tags" { type = map(string) }
