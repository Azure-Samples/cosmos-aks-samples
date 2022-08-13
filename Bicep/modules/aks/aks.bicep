param basename string
param subnetId string
param identity object
param identityid string
param clientId string
param principalId string
param location string = resourceGroup().location
param podBindingSelector string
param podIdentityName string
param podIdentityNamespace string

//param logworkspaceid string  // Uncomment this to configure log analytics workspace


resource aksCluster 'Microsoft.ContainerService/managedClusters@2022-06-02-preview' = {
  name: '${basename}aks'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: identity   
  }
  properties: {
    kubernetesVersion: '1.22.11'
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
      dockerBridgeCidr: '172.17.0.1/16'
      dnsServiceIP: '10.0.0.10'
      serviceCidr: '10.0.0.0/16'
 
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
    enableRBAC: true
    enablePodSecurityPolicy: false
    addonProfiles:{
      /*
	  // Uncomment this to configure log analytics workspace
	  omsagent: {
        config: {
          logAnalyticsWorkspaceResourceID: logworkspaceid
        }
        enabled: true
      }*/
      azureKeyvaultSecretsProvider: {
        enabled: true
      }
      azurepolicy: {
        enabled: false
      }
    }
    
    podIdentityProfile: {
      enabled: true
      userAssignedIdentities: [
        {
          bindingSelector: podBindingSelector
          identity: {
            clientId: clientId
            resourceId: identityid
            objectId: principalId
          }
          name: podIdentityName
          namespace: podIdentityNamespace
        }
      ]
      userAssignedIdentityExceptions: [
        {
          name: 'string'
          namespace: 'string'
          podLabels: {}
        }
      ]
    }
    disableLocalAccounts: false
  }
}











