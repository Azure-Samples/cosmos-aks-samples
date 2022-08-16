param basename string
param location string = resourceGroup().location
resource logworkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview'= {
  name: '${basename}-workspace'
  location: location
}

output laworkspaceId string = logworkspace.id
