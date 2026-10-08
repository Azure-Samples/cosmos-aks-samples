variable "rg_name" {
  type        = string
  description = "Resource Group Name"
}

variable "location" {
  type        = string
  description = "Azure Region"
  default     = "eastus"
}

variable "tenant_id" {
  type        = string
  description = "Microsoft Entra tenant ID used by the application and Key Vault"
}

variable "entra_web_app_client_id" {
  type        = string
  description = "Client ID of the Microsoft Entra web application registration"
}

variable "kubernetes_namespace" {
  type        = string
  description = "Dedicated Kubernetes namespace for the application"
  default     = "todo-app"
}

variable "service_account_name" {
  type        = string
  description = "Kubernetes service account federated with the workload identity"
  default     = "todo-workload-identity"
}

variable "acr_name" {
  type        = string
  description = "ACR Name"
}

variable "acr_sku" {
  type        = string
  description = "ACR SKU: Standard/Premium"
  default     = "Premium"
}

variable "kv_name" {
  type        = string
  description = "Key Vault Name"
}

variable "cosmosdb_account_name" {
  type        = string
  description = "Cosmos DB account name"
}

variable "cosmosdb_sqldb_name" {
  type    = string
  default = "todoapp"
}

variable "cosmosdb_container_name" {
  type    = string
  default = "tasks"
}

variable "throughput" {
  type        = number
  description = "Cosmos DB RU throughput"
  default     = 400
}

variable "uai_name" {
  type        = string
  description = "Managed Identity Name"
  default     = "aks-msi"
}

variable "vnet_name" {
  type        = string
  description = "Virtual Network Name"
  default     = "aks-vnet"
}

variable "address_space" {
  type        = list(string)
  description = "VNET Address Space"
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  type        = string
  description = "Subnet Name"
  default     = "aks-subnet"
}

variable "subnet_prefixes" {
  type        = list(string)
  description = "Subnet prefixes"
  default     = ["10.0.0.0/24"]
}

variable "aks_name" {
  type        = string
  description = "AKS cluster name"
}

variable "vm_size" {
  type        = string
  description = "AKS Node Size"
  default     = "Standard_D4s_v3"
}

variable "node_count" {
  type    = number
  default = 2
}
