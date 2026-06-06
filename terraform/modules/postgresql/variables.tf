variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "prefix" {
  type = string
}

variable "db_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "storage_mb" {
  type    = number
  default = 131072
}

variable "admin_username" {
  type    = string
  default = "cordaadmin"
}

variable "ha_enabled" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "geo_redundant_backup" {
  type    = bool
  default = false
}

variable "keyvault_id" {
  description = "Key Vault to store the generated admin password."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
