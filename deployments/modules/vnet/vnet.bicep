param vnetNamePrefix string
param location string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: '${vnetNamePrefix}-VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/8'
      ]
    }
    subnets: [
      {
        name: 'AKS'
        properties: {
          addressPrefix: '10.240.0.0/16'
        }
      }      
    ]
  }
}
output vnetId string = vnet.id
output vnetName string = vnet.name
output vnetSubnets array = vnet.properties.subnets
output vnetSubnetId string = vnet.properties.subnets[0].id


