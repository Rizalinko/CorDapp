data "azurerm_client_config" "current" {}

# Managed identity for the AKS control plane.
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.prefix}-aks-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Separate workload identity that Corda pods use to read Key Vault secrets.
# Bound to the Kubernetes ServiceAccount via Workload Identity federation.
resource "azurerm_user_assigned_identity" "corda_workload" {
  name                = "${var.prefix}-corda-wi"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.prefix}-aks"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = "${var.prefix}-aks"
  tags                = var.tags

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # System node pool: kube-system and other platform components.
  default_node_pool {
    name           = "system"
    node_count     = 2
    vm_size        = var.system_vm_size
    vnet_subnet_id = var.aks_subnet_id
    os_disk_type   = "Ephemeral"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }

  # CSI secrets provider enables mounting Key Vault secrets as Kubernetes volumes.
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }
}

# Dedicated node pool for Corda nodes. Larger VMs, managed OS disk for PVC stability.
resource "azurerm_kubernetes_cluster_node_pool" "corda" {
  name                  = "corda"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.node_vm_size
  vnet_subnet_id        = var.aks_subnet_id
  os_disk_type          = "Managed"
  mode                  = "User"
  tags                  = var.tags

  enable_auto_scaling = var.min_node_count > 0
  node_count          = var.min_node_count > 0 ? null : var.node_count
  min_count           = var.min_node_count > 0 ? var.min_node_count : null
  max_count           = var.min_node_count > 0 ? var.max_node_count : null

  upgrade_settings {
    max_surge = "1"
  }
}

# Allow each node's kubelet to pull images from ACR without explicit credentials.
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Allow Corda pods to read secrets from Key Vault (read-only).
resource "azurerm_role_assignment" "corda_kv_secrets_user" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.corda_workload.principal_id
}

# Federated identity credential linking the Kubernetes ServiceAccount to the Azure identity.
resource "azurerm_federated_identity_credential" "corda" {
  name                = "${var.prefix}-corda-federated"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.corda_workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject             = "system:serviceaccount:corda:corda"
}
