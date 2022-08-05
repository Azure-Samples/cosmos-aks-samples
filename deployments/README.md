# AKS Cluster, Cosmos DB, Key Vault, and ACR using Bicep

### Overview

This article explains on how to use modules approach for Infrastructure as Code and be able to provision a AKS cluster and few related resources to run a Sample Todo App using Cosmos DB. The AKs is configured to  use a Managed identity and all access is controlled via RBAC. The bicep modules in the repository are designed keeping Base line architecture in mind. You can start using these modules as is or modify to suit the needs.

The bicep modules will provision the following Azure Resources under subscription scope.

1. A Resource Group with Baseline variable
2. A Managed Identity3. 
3. Azure Container Registry for storing images.
4. A VNET required for configuring the AKS
5. A AKS Cluster with monitoring Addon
6. A Cosmos DB SQL API Account along with a Database, Container, and SQL Role to manage RBAC.
7. A Key Vault to store secure keys
8. A Log Analytics workspace


### Resource Provisioning

1. Clone the repo

Clone the repo and move to deployments folder

```bash
cd deployments
```

2. Login to Azure

```bash
az login

az account set -s <Subscription ID>
```


3. Initilaize Parmaters

Refer to [the naming rules and restrictions for Azure resources](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules).

Using the following JSON as template create your own param.json, update your own values for Resource Group Name, Cosmos DB Account Name, and ACR instance Name

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "baseName": {
      "value": "{Resource Group Name}"
    },    
    "cosmosName" :{
      "value": "{Cosmos DB Account Name}"
    },
    "acrName" :{
      "value": "{ACR Instance Name}"
    }
  }
}
```
4. Run Deployment

Run the following script to create the deployment 
```bash
baseline='{Deployment Name}'  # Deployment Name
location='{Location}' # Location for deploying the resources
az deployment sub create --name $baseline --location $location --template-file main.bicep --parameters @param.json
```
The deployment could take somewhere around 20 to 30 mins. Once provisioning is completed you can proceed with the next steps.

5. Attach ACR

Integrate the ACR with the AKS clusters by supplying valid ACR name
```bash
# ensure the below value matches  the acrName field of param.json
acrName=$baseline'acr' 

az aks update -n $baseline'aks' -g $baseline'-RG' --attach-acr $acrName
```

6. Sign in to AKS CLuster
Use [az aks get-credentials][az-aks-get-credentials] to sign in to your AKS cluster. This command also downloads and configures the kubectl client certificate on your development computer.
```bash
# az aks get-credentials -n $baseline'aks' -g $baseline'-RG'
```

7. Enable the AKS Pods to connect to Key Vault
Using the following YAML template create a secretproviderclass.yml, update your own values for Tenant Id, and Kev Vault Name
```yml
# This is a SecretProviderClass example using aad-pod-identity to access the key vault
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kvname-podid
spec:
  provider: azure
  parameters:
    usePodIdentity: "true"               
    keyvaultName: "{Key Vault Name}"       # Set to the name of your key vault
    cloudName: ""                        
    objects:  |
      array:
        - |
          objectName: secret1
          objectType: secret            
          objectVersion: ""              
        - |
          objectName: key1
          objectType: key
          objectVersion: ""
    tenantId: "{Tenant Id}"              # The tenant ID of the key vault
```

8. Apply the SecretProviderClass to your cluster
```bash
kubectl apply -f secretproviderclass.yaml
```

9. Push the container image to ACR
Build the application source code, [publish the container image to the ACR] (https://docs.microsoft.com/en-us/visualstudio/containers/hosting-web-apps-in-docker?view=vs-2022).

10. Prepare Deployment YAML
 Using the following YAML template create a akstododeploy.yml file, update your own values for ACR Name, Image Name, Version and Key Vault Name
```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo
  labels:
    aadpodidbinding: "my-pod-identity"
    app: todo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: todo
  template:
    metadata:
      labels:
        app: todo
        aadpodidbinding: "my-pod-identity"
    spec:
      containers:
      - name: mycontainer
        image: "{ACR Name}/{Image Name}:{Version}"   # update as per your environment
        ports:
        - containerPort: 80
        env:
        - name: KeyVaultName
          value: "{Key Vault Name}" # update as per your environment
      nodeSelector:
        kubernetes.io/os: linux
      volumes:
        - name: secrets-store01-inline
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "azure-kvname-podid"       
---
    
kind: Service
apiVersion: v1
metadata:
  name: todo
spec:
  selector:
    app: todo
    aadpodidbinding: "my-pod-identity"    
  type: LoadBalancer
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
``` 

11. Apply Deployment YAML

```bash
kubectl apply -f akstododeploy.yaml --namespace 'my-app'
```

# Cleanup
Use the below comands to delete the Resource Group and Deployment
```bash
az group delete -g $baseline'-RG' -y
az deployment sub delete -n $baseline
```
