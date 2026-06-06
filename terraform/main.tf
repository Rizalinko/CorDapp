locals {
  prefix = "corda-${var.environment}"
  common_tags = merge(var.tags, {
    environment = var.environment
    managed-by  = "terraform"
    project     = "acmecorp-corda"
  })
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  prefix              = local.prefix
  tags                = local.common_tags
}

module "acr" {
  source              = "./modules/acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  prefix              = local.prefix
  sku                 = var.acr_sku
  tags                = local.common_tags
}

module "keyvault" {
  source              = "./modules/keyvault"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  prefix              = local.prefix
  tags                = local.common_tags
}

module "aks" {
  source                          = "./modules/aks"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  prefix                          = local.prefix
  aks_subnet_id                   = module.networking.aks_subnet_id
  system_vm_size                  = var.aks_system_vm_size
  node_vm_size                    = var.aks_node_vm_size
  node_count                      = var.aks_node_count
  min_node_count                  = var.aks_min_node_count
  max_node_count                  = var.aks_max_node_count
  api_server_authorized_ip_ranges = var.aks_api_server_authorized_ip_ranges
  acr_id                          = module.acr.id
  keyvault_id                     = module.keyvault.id
  tags                            = local.common_tags
}

module "postgresql" {
  source                = "./modules/postgresql"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  prefix                = local.prefix
  db_subnet_id          = module.networking.db_subnet_id
  private_dns_zone_id   = module.networking.postgresql_dns_zone_id
  sku_name              = var.postgresql_sku
  storage_mb            = var.postgresql_storage_mb
  admin_username        = var.postgresql_admin_username
  ha_enabled            = var.postgresql_ha_enabled
  backup_retention_days = var.postgresql_backup_retention_days
  geo_redundant_backup  = var.postgresql_geo_redundant_backup
  keyvault_id           = module.keyvault.id
  tags                  = local.common_tags
}
