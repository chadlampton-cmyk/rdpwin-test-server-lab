variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "workspace_name" { type = string }
variable "friendly_name" { type = string }
variable "app_group_ids" { type = list(string) }
variable "tags" { type = map(string) }
