output "resource_group_name" {
  description = "Resource group containing all Corda infrastructure."
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.cluster_name
}

output "aks_get_credentials" {
  description = "Command to configure kubectl for this cluster."
  value       = "az aks get-credentials --resource-group ${var.resource_group_name} --name ${module.aks.cluster_name}"
}

output "acr_login_server" {
  description = "ACR login server (use as image repository prefix)."
  value       = module.acr.login_server
}

output "postgresql_host" {
  description = "PostgreSQL Flexible Server FQDN."
  value       = module.postgresql.host
}

output "keyvault_uri" {
  description = "Key Vault URI for application secret references."
  value       = module.keyvault.vault_uri
}

output "corda_workload_identity_client_id" {
  description = "Client ID of the Corda workload identity. Annotate the corda ServiceAccount with this value."
  value       = module.aks.corda_workload_identity_client_id
}
