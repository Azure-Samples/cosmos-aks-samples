param acrName string
param location string = resourceGroup().location
param principalId string

resource acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
  }
}
output acrid string = acr.id


@description('This is the built-in role to Pull artifacts from a container registry. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#acrpull')
resource acrPullDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: resourceGroup()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}



resource aksAcrPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id)
  scope: acr
  properties: {
    principalId: principalId
    roleDefinitionId: acrPullDefinition.id
    principalType: 'ServicePrincipal'
  }
}

