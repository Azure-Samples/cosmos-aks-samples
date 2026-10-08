param basename string
param location string = resourceGroup().location
resource azidentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${basename}identity'
  location: location  
}

output identityid string = azidentity.id
output clientId string = azidentity.properties.clientId
output principalId string = azidentity.properties.principalId
