param basename string
param location string = resourceGroup().location
resource logworkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: '${basename}-workspace'
  location: location
}

output laworkspaceId string = logworkspace.id
