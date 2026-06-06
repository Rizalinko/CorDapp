resource "random_password" "admin" {
  length           = 32
  special          = true
  override_special = "!#%()-_=+[]{}<>:"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.prefix}-pg"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "16"
  delegated_subnet_id    = var.db_subnet_id
  private_dns_zone_id    = var.private_dns_zone_id
  administrator_login    = var.admin_username
  administrator_password = random_password.admin.result
  sku_name               = var.sku_name
  storage_mb             = var.storage_mb
  tags                   = var.tags

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup

  dynamic "high_availability" {
    for_each = var.ha_enabled ? [true] : []
    content {
      mode = "ZoneRedundant"
    }
  }
}

resource "azurerm_postgresql_flexible_server_database" "notary" {
  name      = "corda_notary"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_database" "node1" {
  name      = "corda_node1"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_database" "node2" {
  name      = "corda_node2"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Generated admin password stored in Key Vault. Terraform will not rotate it
# after initial creation (ignore_changes keeps the stored value stable).
resource "azurerm_key_vault_secret" "pg_admin_password" {
  name         = "postgresql-admin-password"
  value        = random_password.admin.result
  key_vault_id = var.keyvault_id

  lifecycle {
    ignore_changes = [value]
  }
}
