targetScope = 'subscription'

// Parameters
param rgName string
param acrName string
param cosmosName string
@description('Client ID of the Microsoft Entra web application registration used for interactive sign-in.')
param entraWebAppClientId string
param location string = deployment().location
param kubernetesNamespace string = 'todo-app'
param serviceAccountName string = 'todo-workload-identity'
param databaseName string = 'todoapp'
param containerName string = 'tasks'

var baseName = rgName

module rg 'modules/resource-group/rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
  }
}

module aksIdentity 'modules/Identity/userassigned.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'managedIdentity'
  params: {
    basename: baseName
    location: location
  }
}


resource vnetAKSRes 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: resourceGroup(rg.name)
  name: vnetAKS.outputs.vnetName
}


module vnetAKS 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksVNet'
  params: {
    vnetNamePrefix: 'aks'
    location: location
  }
}

module acrDeploy 'modules/acr/acr.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acrInstance'
  params: {
    acrName: acrName
    principalId: aksCluster.outputs.kubeletPrincipalId
    location: location
  }
}

module akslaworkspace 'modules/laworkspace/la.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'akslaworkspace'
  params: {
    basename: baseName
    location: location
  }
}


resource subnetaks 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: 'aksSubNet'
  parent: vnetAKSRes
}


module aksMangedIDOperator 'modules/Identity/role.bicep' = {
  name: 'aksMangedIDOperator'
  scope: resourceGroup(rg.name)
  params: {
    principalId: aksIdentity.outputs.principalId
    roleGuid: 'f1a07417-d97a-45cb-824c-7a7467783830' //ManagedIdentity Operator Role
  }
}


module aksCluster 'modules/aks/aks.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksCluster'
  dependsOn: [
    aksMangedIDOperator    
  ]
  params: {
    location: location
    basename: baseName
   // logworkspaceid: akslaworkspace.outputs.laworkspaceId   // Uncomment this to configure log analytics workspace
    subnetId: subnetaks.id
    identity: {
      '${aksIdentity.outputs.identityid}' : {}
    }
    workspaceId: akslaworkspace.outputs.laworkspaceId
  }
}

module federatedIdentity 'modules/Identity/federated.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'federatedIdentity'
  params: {
    basename: baseName
    issuerUrl: aksCluster.outputs.oidcIssuerUrl
    subject: 'system:serviceaccount:${kubernetesNamespace}:${serviceAccountName}'
  }
}

module cosmosdb 'modules/cosmos/cosmos.bicep'={
  scope:resourceGroup(rg.name)
  name:'cosmosDB'
  params:{
    location: location
    principalId:aksIdentity.outputs.principalId
    accountName:cosmosName
    subNetId: subnetaks.id
    databaseName: databaseName
    containerName: containerName
  }

}


module keyvault 'modules/keyvault/keyvault.bicep'={
  name :'keyVault'
  scope:resourceGroup(rg.name)  
  params:{
    basename:baseName
    location:location
    principalId:aksIdentity.outputs.principalId
    cosmosEndpoint: cosmosdb.outputs.cosmosEndpoint
    workspaceId: akslaworkspace.outputs.laworkspaceId
  }
}

output tenantId string = subscription().tenantId
output webAppClientId string = entraWebAppClientId
output workloadIdentityClientId string = aksIdentity.outputs.clientId
output workloadIdentityPrincipalId string = aksIdentity.outputs.principalId
output namespaceName string = kubernetesNamespace
output workloadIdentityServiceAccountName string = serviceAccountName
output cosmosEndpoint string = cosmosdb.outputs.cosmosEndpoint
output cosmosDatabaseName string = databaseName
output cosmosContainerName string = containerName
