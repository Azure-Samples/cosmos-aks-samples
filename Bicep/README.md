# Deploy with Bicep

This flow deploys a resource group, user-assigned managed identity, virtual network,
AKS cluster, Azure Container Registry, Cosmos DB account/database/container and
custom data-plane role, Key Vault, and Log Analytics workspace. AKS enables its OIDC
issuer and Workload Identity and uses the supported Kubernetes version selected by
Azure rather than pinning an obsolete version.

Read the shared [application, identity, ingress, and data-migration requirements](../README.md)
before deploying. In particular, create the single-tenant Microsoft Entra web app
registration and its managed-identity federated credential first.

## Parameters

Copy `param.json` and replace these values:

| Parameter | Purpose |
|---|---|
| `rgName` | Resource group and resource-name prefix |
| `cosmosName` | Globally unique Cosmos DB account name |
| `acrName` | Globally unique registry name |
| `entraWebAppClientId` | Microsoft Entra web application client ID |

The web app client ID is not the workload managed identity client ID. The latter is
created by this deployment and returned in its outputs.

## Validate and deploy

```powershell
cd Bicep
az bicep build --file main.bicep
az bicep build --file main.test.bicep

$deploymentName = "<deployment-name>"
$location = "<azure-region>"
az deployment sub create `
  --name $deploymentName `
  --location $location `
  --template-file main.bicep `
  --parameters "@param.json"
```

The deployment outputs the tenant ID, Entra web app client ID, workload identity
client and principal IDs, Kubernetes namespace/service account names, and Cosmos
endpoint/database/container values. Use those outputs to replace every placeholder
in `akstododeploy.yml`.

```powershell
$outputs = az deployment sub show --name $deploymentName `
  --query properties.outputs | ConvertFrom-Json
$outputs.workloadIdentityClientId.value
$outputs.workloadIdentityPrincipalId.value
```

The Bicep deployment creates the AKS OIDC federated credential for
`system:serviceaccount:todo-app:todo-workload-identity`. Separately, the Entra web
app registration must trust the returned managed identity principal/object ID with:

- issuer `https://login.microsoftonline.com/<tenant-id>/v2.0`
- subject equal to the managed identity principal/object ID
- audience `api://AzureADTokenExchange`

That second credential enables Microsoft.Identity.Web
`SignedAssertionFromManagedIdentity`; do not create or store a production client
secret.

## Build and push the application

The Dockerfile builds .NET 10 and listens on `8080`. Docker or Podman can produce the
same OCI image:

```powershell
cd ..\Application
docker build -t <acr-name>.azurecr.io/todo:<tag> .
docker push <acr-name>.azurecr.io/todo:<tag>

# Podman equivalents
podman build -t <acr-name>.azurecr.io/todo:<tag> .
podman push <acr-name>.azurecr.io/todo:<tag>
```

Authenticate the selected engine to ACR before pushing. The Bicep modules grant the
AKS kubelet identity `AcrPull`; no separate `az aks update --attach-acr` step is
required.

## Deploy the workload

`akstododeploy.yml` contains:

- namespace `todo-app`;
- service account `todo-workload-identity`;
- one replica using Workload Identity;
- Microsoft.Identity.Web `SignedAssertionFromManagedIdentity` configuration;
- health probes on container port `8080`; and
- a `ClusterIP` service mapping port `80` to `8080`.

Replace all placeholders, then apply it:

```powershell
kubectl apply -f ..\Bicep\akstododeploy.yml
kubectl get pods,service -n todo-app
```

The service is intentionally internal. Provide an HTTPS ingress or reverse proxy,
DNS, and a certificate for the hostname registered in Entra. Configure
`ForwardedHeaders__KnownProxies__0` (and subsequent indices) with trusted proxy IPs
when forwarded headers are used.

Do not increase `replicas` until a durable, shared, protected ASP.NET Core Data
Protection key ring replaces the manifest's `emptyDir`. Cosmos local authentication
is disabled and the custom role supports full CRUD, including replace and delete.
The container partition key remains `/id`; documents without `ownerId` require an
explicit migration.

## Cleanup

```powershell
az group delete --name "<resource-group-name>" --yes
az deployment sub delete --name "<deployment-name>"
```
