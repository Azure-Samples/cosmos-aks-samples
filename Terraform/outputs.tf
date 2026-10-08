output "vnetId" {
  value = azurerm_virtual_network.this.id
}

output "vnetName" {
  value = azurerm_virtual_network.this.name
}

output "vnetSubnetId" {
  value = azurerm_subnet.this.id
}

output "identityId" {
  value = azurerm_user_assigned_identity.this.id
}

output "clientId" {
  value = azurerm_user_assigned_identity.this.client_id
}

output "workload_identity_client_id" {
  value = azurerm_user_assigned_identity.this.client_id
}

output "entra_web_app_client_id" {
  value = var.entra_web_app_client_id
}

output "principalId" {
  value = azurerm_user_assigned_identity.this.principal_id
}

output "acrId" {
  value = azurerm_container_registry.this.id
}

output "tenantId" {
  value = var.tenant_id
}

output "aksName" {
  value = azurerm_kubernetes_cluster.this.name
}

output "kvName" {
  value = azurerm_key_vault.this.name
}

output "kubernetes_namespace" {
  value = var.kubernetes_namespace
}

output "service_account_name" {
  value = var.service_account_name
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.this.endpoint
}

output "cosmos_database_name" {
  value = var.cosmosdb_sqldb_name
}

output "cosmos_container_name" {
  value = var.cosmosdb_container_name
}