targetScope = 'subscription'

// Parameters
param rgName string
param acrName string
param location string =deployment().location

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


resource vnetAKSRes 'Microsoft.Network/virtualNetworks@2022-01-01'existing = {
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
  dependsOn: [
    rg
  ]
}

module acrDeploy 'modules/acr/acr.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acrInstance'
  params: {
    acrName: acrName
    principalId: aksIdentity.outputs.principalId
    location: location
  }
}

/*

// Uncomment this to configure log analytics workspace

module akslaworkspace 'modules/laworkspace/la.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'akslaworkspace'
  params: {
    basename: baseName
    location: location
  }
}

*/

resource subnetaks 'Microsoft.Network/virtualNetworks/subnets@2022-01-01'existing = {
  name: 'aksSubnet'
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
   // logworkspaceid: akslaworkspace.outputs.laworkspaceId  // Uncomment this to configure log analytics workspace
    podBindingSelector: 'my-pod-identity'
    podIdentityName: 'my-pod-identity'
    podIdentityNamespace: 'my-app'
    subnetId: subnetaks.id
    clientId: aksIdentity.outputs.clientId
    identityid: aksIdentity.outputs.identityid
    identity: {
      '${aksIdentity.outputs.identityid}' : {}
    }
    principalId: aksIdentity.outputs.principalId
  }
}



