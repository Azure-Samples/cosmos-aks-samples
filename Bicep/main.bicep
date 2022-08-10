targetScope = 'subscription'

// Parameters
param baseName string
param acrName string
param cosmosName string

//param pubkeydata string


var rgName = '${baseName}-RG'

/*
// Must be unique name
var acrName = '${uniqueString(rgName)}acr'
*/

var location =deployment().location

module rg 'modules/resource-group/rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
  }
}

module aksIdentity 'modules/Identity/userassigned.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksIdentity'
  params: {
    basename: baseName
    location: location
  }
}


resource vnetAKSRes 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: vnetAKS.outputs.vnetName
}


module vnetAKS 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'AKS-VNet'
  params: {
    vnetNamePrefix: 'aks'
    location: location
  }
  dependsOn: [
    rg
  ]
}

module acrDeploy 'modules/acr/acr.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acrDeploy'
  params: {
    acrName: acrName
    principalId: aksIdentity.outputs.principalId
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


resource subnetaks 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: 'AKS'
  parent: vnetAKSRes
}


/*
module aksVMContrib 'modules/Identity/role.bicep' = {
  name: 'aksVMContrib'
  scope: resourceGroup(rg.name)
  dependsOn: [
    aksCluster    
  ]
  params: {
    principalId: aksIdentity.outputs.principalId
    roleGuid: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' //Virtual Machine Contributor
  }
}
*/

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
    location: deployment().location
    basename: baseName
    logworkspaceid: akslaworkspace.outputs.laworkspaceId
    podBindingSelector: 'my-pod-identity'
    podIdentityName: 'my-pod-identity'
    podIdentityNamespace: 'my-app'
    //publicKey: pubkeydata
    subnetId: subnetaks.id
    clientId: aksIdentity.outputs.clientId
    identityid: aksIdentity.outputs.identityid
    identity: {
      '${aksIdentity.outputs.identityid}' : {}
    }
    principalId: aksIdentity.outputs.principalId
  }
}

module cosmosdb 'modules/cosmos/cosmos.bicep'={
  scope:resourceGroup(rg.name)
  name:'cosmosdb'
  params:{
    location: deployment().location
    principalId:aksIdentity.outputs.principalId
    accountName:cosmosName
  }

}


module keyvault 'modules/keyvault/keyvault.bicep'={
  name :'keyvault'
  scope:resourceGroup(rg.name)  
  params:{
    basename:baseName
    location:deployment().location
    principalId:aksIdentity.outputs.principalId
    cosmosEndpoint: cosmosdb.outputs.cosmosEndpoint
  }

}

