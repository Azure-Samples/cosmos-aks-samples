param basename string
param subnetId string
param identity object
param location string = resourceGroup().location
param workspaceId string


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
    addonProfiles:{
	    omsagent: {
        config: {
          logAnalyticsWorkspaceResourceID: workspaceId
        }
        enabled: true
      }
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
      defender: {
        logAnalyticsWorkspaceResourceId: workspaceId
        securityMonitoring: {
          enabled: true
        }
      }
    }
  } 
}

output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL


var aksDiagCategories = [
  'cluster-autoscaler'
  'kube-controller-manager'
  'kube-audit-admin'
  'guard'
]

// TODO: Update diagnostics to be its own module
// Blocking issue: https://github.com/Azure/bicep/issues/622
// Unable to pass in a `resource` scope or unable to use string interpolation in resource types
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(workspaceId)) {
  name: 'aks-diagnostics'
  scope: aksCluster
  properties: {
    workspaceId: workspaceId
    logs: [for category in aksDiagCategories: {
      category: category
      enabled: true
    }]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
