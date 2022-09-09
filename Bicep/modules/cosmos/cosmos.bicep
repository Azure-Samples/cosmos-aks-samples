@description('Location for all resources.')
param location string = resourceGroup().location

@description('Cosmos DB account name, max length 44 characters')
param accountName string// = toLower('rgName-${uniqueString(resourceGroup().id)}-cosmossql')

@description('Friendly name for the SQL Role Definition')
param roleDefinitionName string = 'My Read Write Role- No Delete'

@description('Resource Id of the Subnet to enable service endpoints in Cosmos')
param subNetId string

@description('Data actions permitted by the Role Definition')
param dataActions array = [
    'Microsoft.DocumentDB/databaseAccounts/readMetadata'
    'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
    'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed'
    'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
    'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/upsert'
    'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/create'
]

@description('Object ID of the AAD identity. Must be a GUID.')
param principalId string

var locations = [
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
]
var roleDefinitionId = guid('sql-role-definition-', principalId, databaseAccount.id)
var roleAssignmentId = guid(roleDefinitionId, principalId, databaseAccount.id)

resource databaseAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: accountName
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: locations
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: true      // set to false if you want to use master keys in addition to RBAC
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false   
    isVirtualNetworkFilterEnabled: true     // set to false if you want to use public endpoint for Cosmos
    //remove virtualNetworkRules if you want to use public endpoint for Cosmos
    virtualNetworkRules: [
          {
              id: subNetId
              ignoreMissingVNetServiceEndpoint: false
          }
      ]
  }
}
output cosmosEndpoint string = databaseAccount.name

resource sqlRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2022-05-15' = {
  name: '${databaseAccount.name}/${roleDefinitionId}'
  properties: {
    roleName: roleDefinitionName
    type: 'CustomRole'
    assignableScopes: [
      databaseAccount.id
    ]
    permissions: [
      {
        dataActions: dataActions
      }
    ]
  }
}

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15' = {
  name: '${databaseAccount.name}/${roleAssignmentId}'
  properties: {
    roleDefinitionId: sqlRoleDefinition.id
    principalId: principalId
    scope: databaseAccount.id
  }
}


resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-10-15' = {
  name: '${databaseAccount.name}/todoapp'
  properties: {
    resource: {
      id: 'todoapp'
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
  name: '${database.name}/${'tasks'}'
  properties: {
    resource: {
      id: 'tasks'
      partitionKey: {
        paths: [
          '/id'
        ]
        //kind: 'Hash'
      }
    }
  }
}


