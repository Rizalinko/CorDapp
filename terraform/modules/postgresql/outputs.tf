output "host" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "server_id" {
  value = azurerm_postgresql_flexible_server.main.id
}

output "admin_username" {
  value = azurerm_postgresql_flexible_server.main.administrator_login
}

output "admin_password_secret_name" {
  description = "Name of the Key Vault secret holding the admin password."
  value       = azurerm_key_vault_secret.pg_admin_password.name
}
