resource "azurerm_key_vault" "this" {
  name                       = var.kv_name
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 10
  purge_protection_enabled   = false
  sku_name                   = "standard"
}

resource "azurerm_key_vault_access_policy" "user_assigned_identity" {
  key_vault_id            = azurerm_key_vault.this.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_user_assigned_identity.this.principal_id
  certificate_permissions = ["Get", "List"]
  key_permissions         = ["Get", "List"]
  secret_permissions      = ["Get", "List", "Set", "Delete"]
  storage_permissions     = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "this" {
  key_vault_id       = azurerm_key_vault.this.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "List", "Set", "Delete"]
}

resource "azurerm_key_vault_secret" "cosmosdb_endpt" {
  name         = "CosmosEndpoint"
  value        = azurerm_cosmosdb_account.this.endpoint
  key_vault_id = azurerm_key_vault.this.id
  depends_on = [
    azurerm_key_vault_access_policy.this
  ]
}