param basename string
param subnetId string
param identity object
param location string = resourceGroup().location

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: '${basename}aks'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: identity   
  }
  properties: {
    nodeResourceGroup: '${basename}-aksInfraRG'
    dnsPrefix: '${basename}aks'
    agentPoolProfiles: [
      {
        name: 'default'
        count: 2
        vmSize: 'Standard_D4s_v3'
        mode: 'System'
        maxCount: 5
        minCount: 2
        osType: 'Linux'
        osSKU: 'Ubuntu'
        enableAutoScaling:true
        maxPods: 50
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: subnetId
        enableNodePublicIP:false
      }
    ]

    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: 'azure'
      outboundType: 'loadBalancer'
      dnsServiceIP: '10.0.0.10'
      serviceCidr: '10.0.0.0/16'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
    enableRBAC: true
    enablePodSecurityPolicy: false

    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
        }
      }
      azurepolicy: {
        enabled: false
      }
    }
    
    oidcIssuerProfile: {
      enabled: true
    }
    disableLocalAccounts: false
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}

output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL
output kubeletPrincipalId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
