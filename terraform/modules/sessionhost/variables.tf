variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "subnet_id" { type = string }
variable "vm_name" { type = string }
variable "computer_name" { type = string }
variable "vm_size" { type = string }
variable "admin_username" { type = string }
variable "admin_password" { type = string }
variable "image_publisher" { type = string }
variable "image_offer" { type = string }
variable "image_sku" { type = string }
variable "image_version" { type = string }
variable "registration_token" {
  type      = string
  sensitive = true
}
variable "enable_aad_login_extension" { type = bool }
variable "tags" { type = map(string) }
