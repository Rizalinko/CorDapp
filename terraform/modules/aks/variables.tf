variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "prefix" {
  type = string
}

variable "aks_subnet_id" {
  type = string
}

variable "system_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "min_node_count" {
  description = "Set > 0 to enable cluster autoscaler."
  type        = number
  default     = 0
}

variable "max_node_count" {
  type    = number
  default = 6
}

variable "acr_id" {
  description = "Resource ID of the ACR to grant AcrPull to the cluster kubelet identity."
  type        = string
}

variable "keyvault_id" {
  description = "Resource ID of the Key Vault to grant Corda workload identity read access."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
