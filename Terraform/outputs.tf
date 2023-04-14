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

output "principalId" {
  value = azurerm_user_assigned_identity.this.principal_id
}

output "acrId" {
  value = azurerm_container_registry.this.id
}

output "tenantId" {
  value = azurerm_user_assigned_identity.this.tenant_id
}

output "aksName" {
  value = azurerm_kubernetes_cluster.this.name
}

output "kvName" {
  value = azurerm_key_vault.this.name 
}