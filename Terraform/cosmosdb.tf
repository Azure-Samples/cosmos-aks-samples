resource "azurerm_cosmosdb_account" "this" {
  name                               = var.cosmosdb_account_name
  location                           = azurerm_resource_group.this.location
  resource_group_name                = azurerm_resource_group.this.name
  offer_type                         = "Standard"
  kind                               = "GlobalDocumentDB"
  automatic_failover_enabled         = false
  local_authentication_enabled       = false
  access_key_metadata_writes_enabled = false
  minimal_tls_version                = "Tls12"
  public_network_access_enabled      = true
  is_virtual_network_filter_enabled  = true
  geo_location {
    location          = azurerm_resource_group.this.location
    failover_priority = 0
  }
  consistency_policy {
    consistency_level = "Session"
  }
  virtual_network_rule {
    id                                   = azurerm_subnet.this.id
    ignore_missing_vnet_service_endpoint = false
  }
}

resource "azurerm_cosmosdb_sql_database" "this" {
  name                = var.cosmosdb_sqldb_name
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  throughput          = var.throughput
}

resource "azurerm_cosmosdb_sql_container" "this" {
  name                  = var.cosmosdb_container_name
  resource_group_name   = azurerm_resource_group.this.name
  account_name          = azurerm_cosmosdb_account.this.name
  database_name         = azurerm_cosmosdb_sql_database.this.name
  partition_key_paths   = ["/id"]
  partition_key_version = 1
}

resource "random_uuid" "role_definition" {}

resource "random_uuid" "role_assignment" {}

resource "azurerm_cosmosdb_sql_role_definition" "custom" {
  name                = random_uuid.role_definition.result
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  type                = "CustomRole"
  assignable_scopes   = [azurerm_cosmosdb_account.this.id]
  permissions {
    data_actions = [
      "Microsoft.DocumentDB/databaseAccounts/readMetadata",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/upsert",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/create",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/replace",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/delete"
    ]
  }
}

resource "azurerm_cosmosdb_sql_role_assignment" "user_assigned_identity" {
  name                = random_uuid.role_assignment.result
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.custom.id
  principal_id        = azurerm_user_assigned_identity.this.principal_id
  scope               = azurerm_cosmosdb_account.this.id
}