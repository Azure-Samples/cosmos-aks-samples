resource "random_string" "kv" {
  length  = 8
  special = false
}
resource "azurerm_key_vault" "this" {
  name                       = "${var.kv_name}-${random_string.kv.result}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = var.tenant_id
  soft_delete_retention_days = 10
  purge_protection_enabled   = true
  rbac_authorization_enabled = true
  sku_name                   = "standard"
}

resource "azurerm_role_assignment" "key_vault_workload_identity" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "key_vault_deployer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "cosmosdb_endpt" {
  name         = "CosmosEndpoint"
  value        = azurerm_cosmosdb_account.this.endpoint
  key_vault_id = azurerm_key_vault.this.id
  depends_on = [
    azurerm_role_assignment.key_vault_deployer
  ]
}