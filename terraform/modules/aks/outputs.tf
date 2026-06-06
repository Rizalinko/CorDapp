output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity federation."
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "corda_workload_identity_client_id" {
  description = "Client ID to annotate the Kubernetes corda ServiceAccount for Key Vault access."
  value       = azurerm_user_assigned_identity.corda_workload.client_id
}

output "corda_workload_identity_id" {
  value = azurerm_user_assigned_identity.corda_workload.id
}
