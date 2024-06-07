param cosmosEndpoint string 
param location string = resourceGroup().location
param principalId string
param basename string
param workspaceId string

resource keyvault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${basename}kv'
  location: location 
  properties: {
    accessPolicies: [
      {
        //applicationId: 'string'
        objectId: principalId
        permissions: {
          certificates: [
            'get'
            'list'
          ]
          keys: [
            'get'
            'list'
          ]
          secrets: [
            'get'
            'list'
          ]
          storage: [
            'get'
            'list'
          ]
        }
        tenantId: subscription().tenantId
      }
    ]
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 10
    tenantId:  subscription().tenantId
  }
}

resource logs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'logs'
  scope: keyvault
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
  }
}


resource kvSecretCosmosEndpoint 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: 'CosmosEndpoint'  
  parent: keyvault
  properties: {
    attributes: {
      enabled: true
      //exp: int
     // nbf: int
    }
    contentType: 'string'
    value: 'https://${cosmosEndpoint}.documents.azure.com:443/' 
  }
}
