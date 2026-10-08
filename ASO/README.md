# Deploy with Azure Service Operator v2

This flow uses Bicep for the AKS foundation and Azure Service Operator (ASO) v2
custom resources for Cosmos DB. The foundation contains the resource group,
user-assigned managed identity, virtual network, AKS cluster, Azure Container
Registry, and Log Analytics workspace. AKS enables OIDC and Workload Identity.

Read the shared [application, identity, ingress, and data-migration requirements](../README.md)
first. Create the single-tenant Microsoft Entra web app registration before
deployment.

## Deploy the AKS foundation

Replace the values in `param.json`:

| Parameter | Purpose |
|---|---|
| `rgName` | AKS foundation resource group/name prefix |
| `acrName` | Globally unique registry name |
| `cosmosName` | Cosmos account name used for output placeholders |
| `entraWebAppClientId` | Microsoft Entra web application client ID |

```powershell
cd ASO
az bicep build --file main.bicep

$deploymentName = "<deployment-name>"
$location = "<azure-region>"
az deployment sub create `
  --name $deploymentName `
  --location $location `
  --template-file main.bicep `
  --parameters "@param.json"
```

The deployment outputs the AKS subnet resource ID and workload identity client and
principal IDs. The Entra web app client ID is different from the workload identity
client ID.

The Bicep deployment creates the AKS OIDC credential for
`system:serviceaccount:todo-app:todo-workload-identity`. Also add a federated
identity credential to the Entra web app registration:

- issuer `https://login.microsoftonline.com/<tenant-id>/v2.0`
- subject equal to the managed identity principal/object ID
- audience `api://AzureADTokenExchange`

This separate credential enables production
`SignedAssertionFromManagedIdentity`; do not create a production client secret.

## Install ASO v2

Connect `kubectl` to the cluster, then install and configure
[Azure Service Operator v2](https://azure.github.io/azure-service-operator/).
The operator identity needs permission to create the resources represented by
`cosmos-deploy-aso.yml`.

## Create Cosmos DB resources

Replace the placeholders in `cosmos-deploy-aso.yml`, including location, ASO resource
group, Cosmos account name, AKS subnet resource ID, and workload identity principal
ID.

ASO v2 supports the `SqlRoleAssignment` resource used here but does not currently
provide the custom Cosmos `SqlRoleDefinition` CRD needed by this sample. Create that
role externally before applying the assignment:

```powershell
$asoResourceGroup = "<aso-resource-group-name>"
$cosmosAccount = "<cosmos-account-name>"

# Replace {SQL ROLE NAME} in sql-role-definition.json first.
az cosmosdb sql role definition create `
  --resource-group $asoResourceGroup `
  --account-name $cosmosAccount `
  --body "@sql-role-definition.json"

$roleDefinitionId = az cosmosdb sql role definition list `
  --resource-group $asoResourceGroup `
  --account-name $cosmosAccount `
  --query "[?roleName=='<sql-role-name>'].id | [0]" `
  --output tsv
$cosmosResourceId = az cosmosdb show `
  --resource-group $asoResourceGroup `
  --name $cosmosAccount `
  --query id --output tsv
```

Put `$roleDefinitionId`, `$cosmosResourceId`, and a new role-assignment GUID into the
corresponding placeholders in `cosmos-deploy-aso.yml`. Then apply and observe:

```powershell
kubectl apply -f cosmos-deploy-aso.yml
kubectl get resourcegroup,databaseaccount,sqldatabase,sqldatabasecontainer,sqlroleassignment -n todo-app
```

The custom role supports query, read, create, upsert, replace, and delete. Cosmos
local authentication is disabled. The container partition key remains `/id`.

## Build and deploy the application

Build the .NET 10 image, which listens on port `8080`, with Docker or Podman:

```powershell
cd ..\Application
docker build -t <acr-name>.azurecr.io/todo:<tag> .
docker push <acr-name>.azurecr.io/todo:<tag>

# Podman equivalents
podman build -t <acr-name>.azurecr.io/todo:<tag> .
podman push <acr-name>.azurecr.io/todo:<tag>
```

Replace all placeholders in `ASO\akstodo-appdeploy.yml`, using the Bicep outputs and
the ASO-created Cosmos endpoint, then apply:

```powershell
kubectl apply -f ..\ASO\akstodo-appdeploy.yml
kubectl get pods,service -n todo-app
```

The manifest uses Workload Identity, one replica, health probes on `8080`, and a
`ClusterIP` service mapping port `80` to `8080`. Supply TLS termination, ingress or a
reverse proxy, DNS, and certificates for the Entra-registered hostname. Set
`ForwardedHeaders__KnownProxies__0` and additional indexed values to trusted proxy
IPs when applicable.

Do not scale above one replica until a durable, shared, protected ASP.NET Core Data
Protection key ring is configured. Existing Cosmos documents without `ownerId` are
intentionally inaccessible and require an explicit owner migration.

## Cleanup

Delete the application and ASO resource namespace, then delete the foundation:

```powershell
kubectl delete namespace todo-app
az group delete --name "<foundation-resource-group>" --yes
az deployment sub delete --name "<deployment-name>"
```
