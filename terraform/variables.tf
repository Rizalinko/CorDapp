variable "environment" {
  description = "Deployment environment: dev, staging, or prod."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group to create."
  type        = string
}

# AKS

variable "aks_system_vm_size" {
  description = "VM size for the AKS system node pool (kube-system workloads)."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "aks_node_vm_size" {
  description = "VM size for the Corda user node pool."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "aks_node_count" {
  description = "Number of nodes in the Corda user node pool."
  type        = number
  default     = 3
}

variable "aks_min_node_count" {
  description = "Minimum node count for autoscaling (0 disables autoscaling)."
  type        = number
  default     = 0
}

variable "aks_max_node_count" {
  description = "Maximum node count for autoscaling. Ignored when aks_min_node_count is 0."
  type        = number
  default     = 6
}

variable "aks_api_server_authorized_ip_ranges" {
  description = "CIDR ranges allowed to reach the AKS API server. Set in prod.tfvars to your egress IPs. Empty disables IP restriction."
  type        = list(string)
  default     = []
}

# ACR

variable "acr_sku" {
  description = "ACR SKU. Use Premium for geo-replication in production."
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard, or Premium."
  }
}

# PostgreSQL

variable "postgresql_sku" {
  description = "SKU name for Azure PostgreSQL Flexible Server (e.g. Standard_D4s_v5)."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "postgresql_storage_mb" {
  description = "Storage in MB for the PostgreSQL server."
  type        = number
  default     = 131072
}

variable "postgresql_admin_username" {
  description = "PostgreSQL administrator login name."
  type        = string
  default     = "cordaadmin"
}

variable "postgresql_ha_enabled" {
  description = "Enable zone-redundant high availability for PostgreSQL."
  type        = bool
  default     = false
}

variable "postgresql_backup_retention_days" {
  description = "Number of days to retain PostgreSQL backups (7 to 35)."
  type        = number
  default     = 7
}

variable "postgresql_geo_redundant_backup" {
  description = "Enable geo-redundant backups for PostgreSQL."
  type        = bool
  default     = false
}

# Tags

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
