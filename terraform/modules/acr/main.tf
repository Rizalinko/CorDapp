resource "azurerm_container_registry" "main" {
  # ACR names are alphanumeric only (no hyphens), globally unique, 5 to 50 chars.
  name                = lower(replace("${var.prefix}acr", "-", ""))
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false
  tags                = var.tags
}
