@description('Location for all resources.')
param location string = resourceGroup().location

@description('Cosmos DB account name, max length 44 characters')
param accountName string = toLower('rgName-${uniqueString(resourceGroup().id)}-cosmossql')

@description('Friendly name for the SQL Role Definition')
param roleDefinitionName string = 'My Read Write Role- No Delete'

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

resource databaseAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: accountName
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: locations
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
  }
}
output cosmosEndpoint string = databaseAccount.name

resource sqlRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-04-15' = {
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

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-04-15' = {
  name: '${databaseAccount.name}/${roleAssignmentId}'
  properties: {
    roleDefinitionId: sqlRoleDefinition.id
    principalId: principalId
    scope: databaseAccount.id
  }
}


resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-10-15' = {
  name: '${databaseAccount.name}/ToDoApp'
  properties: {
    resource: {
      id: 'ToDoApp'
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
  name: '${database.name}/${'Tasks'}'
  properties: {
    resource: {
      id: 'Tasks'
      partitionKey: {
        paths: [
          '/id'
        ]
        //kind: 'Hash'
      }
    }
  }
}

/*
      /*indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/myPathToNotIndex/*'
          }
        ]
        compositeIndexes: [
          [
            {
              path: '/name'
              order: 'ascending'
            }
            {
              path: '/age'
              order: 'descending'
            }
          ]
        ]
        spatialIndexes: [
          {
            path: '/location/*'
            types: [
              'Point'
              'Polygon'
              'MultiPolygon'
              'LineString'
            ]
          }
        ]
      }
      defaultTtl: 86400
      uniqueKeyPolicy: {
        uniqueKeys: [
          {
            paths: [
              '/phoneNumber'
            ]
          }
        ]
      }
    }
    options: {
      throughput: throughput
    }
  }
}
*/
