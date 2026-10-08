# Deploy with Terraform

This flow uses Terraform `>= 1.5` and AzureRM `~> 5.8` to deploy a resource group,
user-assigned managed identity, virtual network, AKS cluster, Azure Container
Registry, Cosmos DB account/database/container and custom data-plane role, and Key
Vault. AKS enables its OIDC issuer and Workload Identity and follows the stable
Kubernetes upgrade channel.

Read the shared [application, identity, ingress, and data-migration requirements](../README.md)
before deploying. Create the single-tenant Microsoft Entra web app registration and
its managed-identity federated credential first.

## Configure

Create an untracked `terraform.tfvars`:

```hcl
rg_name                 = "<resource-group-name>"
location                = "<azure-region>"
tenant_id               = "<tenant-id>"
entra_web_app_client_id = "<entra-web-app-client-id>"
acr_name                = "<globally-unique-acr-name>"
kv_name                 = "<globally-unique-key-vault-name>"
cosmosdb_account_name   = "<globally-unique-cosmos-name>"
aks_name                = "<aks-name>"
```

`entra_web_app_client_id` identifies website authentication. It is distinct from
the created workload managed identity's `clientId` output.

## Format, validate, plan, and apply

```powershell
cd Terraform
terraform fmt -check
terraform init
terraform validate
terraform plan -out main.tfplan
terraform apply main.tfplan
```

For validation that must not initialize a remote backend, use
`terraform init -backend=false`.

Authentication uses the normal AzureRM provider credential chain. A Conditional
Access policy with token protection can prevent local Azure CLI credentials from
being used by Terraform. If that applies, run these commands from a policy-compliant
Cloud Shell or CI workload-identity context instead of bypassing policy.

Terraform outputs the tenant ID, Entra web app client ID, workload identity client
and principal IDs, namespace/service-account names, and Cosmos values:

```powershell
terraform output
terraform output -raw workload_identity_client_id
terraform output -raw principalId
```

Terraform creates the AKS OIDC federated credential for
`system:serviceaccount:todo-app:todo-workload-identity`. Separately, configure the
Entra web app registration to trust the managed identity principal/object ID:

- issuer `https://login.microsoftonline.com/<tenant-id>/v2.0`
- subject equal to the managed identity principal/object ID
- audience `api://AzureADTokenExchange`

This enables production `SignedAssertionFromManagedIdentity`. Never place a client
secret in Terraform configuration or state, Kubernetes, or Key Vault.

## Build and deploy the application

Build .NET 10 for container port `8080` and push with either OCI engine:

```powershell
cd ..\Application
docker build -t <acr-name>.azurecr.io/todo:<tag> .
docker push <acr-name>.azurecr.io/todo:<tag>

# Podman equivalents
podman build -t <acr-name>.azurecr.io/todo:<tag> .
podman push <acr-name>.azurecr.io/todo:<tag>
```

Replace every placeholder in `Terraform\akstododeploy.yml` with the Terraform
outputs and image values, then apply it:

```powershell
kubectl apply -f ..\Terraform\akstododeploy.yml
kubectl get pods,service -n todo-app
```

The manifest uses one replica and a `ClusterIP` service (service port `80` to
container port `8080`). The operator must provide TLS termination, ingress or a
reverse proxy, DNS, and certificates. When applicable, configure
`ForwardedHeaders__KnownProxies__0` and further indexed entries with only trusted
proxy IPs.

Keep one replica until a durable, shared, protected ASP.NET Core Data Protection key
ring is configured. Cosmos local authentication is disabled; the custom role permits
query, read, create, upsert, replace, and delete. The partition key stays `/id`, and
documents lacking `ownerId` remain inaccessible until explicitly migrated.

## Cleanup

```powershell
terraform destroy
```
