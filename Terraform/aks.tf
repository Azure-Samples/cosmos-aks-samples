resource "azurerm_kubernetes_cluster" "this" {
  name                = var.aks_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  node_resource_group = "${var.aks_name}-node-rg"
  kubernetes_version  = "1.26.0"
  dns_prefix          = "${var.aks_name}-dns"

  # workload identity 
  workload_identity_enabled = true 
  oidc_issuer_enabled = true 

  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size             = var.vm_size
    min_count           = 2
    max_count           = 5
    enable_auto_scaling = true
    max_pods            = 50
    vnet_subnet_id      = azurerm_subnet.this.id
  }

  network_profile {
    network_plugin     = "azure"
    load_balancer_sku  = "standard"
    outbound_type      = "loadBalancer"
    dns_service_ip     = "20.0.0.10" # modify if conflicting.
    service_cidr       = "20.0.0.0/24"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = ["${azurerm_user_assigned_identity.this.id}"]
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  azure_policy_enabled              = false
  role_based_access_control_enabled = true
  private_cluster_enabled           = false
}

resource "azurerm_federated_identity_credential" "this" {
  name                = "aksfederatedidentity"
  resource_group_name = azurerm_resource_group.this.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.this.id
  subject             = "system:serviceaccount:default:workload-identity-sa" # system:serviceaccount:namespace:service-acct-name - modify based on namespace/service acct name
}