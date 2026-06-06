data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "${var.prefix}-kv"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  enable_rbac_authorization  = true
  tags                       = var.tags
}

# Grant the identity running Terraform permission to write secrets so subsequent
# modules (postgresql) can store generated passwords here.
resource "azurerm_role_assignment" "terraform_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
