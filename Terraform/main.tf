data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = var.rg_name
  location = var.location
}