# Cosmos DB ToDo application on AKS

This sample is an ASP.NET Core MVC application on **.NET 10** that stores per-user
ToDo items in Azure Cosmos DB for NoSQL. It can be provisioned with
[Bicep](Bicep/README.md), [Terraform](Terraform/readme.md), or
[Azure Service Operator (ASO) v2](ASO/README.md).

## Architecture and security

- The application container listens on port `8080`. The Kubernetes services are
  `ClusterIP` services that forward service port `80` to container port `8080`.
- Microsoft Entra user sign-in and AKS Workload Identity are separate:
  - [Microsoft.Identity.Web](https://learn.microsoft.com/entra/identity-platform/scenario-web-app-sign-user-overview)
    authenticates website users against one Microsoft Entra tenant.
  - [AKS Workload Identity](https://learn.microsoft.com/azure/aks/workload-identity-overview)
    authenticates the pod to Azure so `DefaultAzureCredential` can access Cosmos DB
    and, when configured, Key Vault.
- Cosmos DB local/key authentication is disabled. The workload managed identity
  receives a custom Cosmos data-plane role with query, read, create, upsert,
  replace, and delete permissions.
- Items are owner-scoped by the signed-in user's immutable Microsoft Entra `oid`
  claim. Existing documents without `ownerId` are intentionally invisible; migrate
  them explicitly to an owner before using this version. The Cosmos container
  partition key remains `/id`.
- Each deployment manifest intentionally uses one replica. ASP.NET Core Data
  Protection keys currently use pod-local ephemeral storage; configure a durable,
  shared, protected key ring before scaling above one replica.
- The sample does not expose public HTTP. The operator must supply TLS termination,
  ingress or another reverse proxy, DNS, and certificates. Set
  `ForwardedHeaders:KnownProxies` to the trusted proxy IP addresses so generated
  OpenID Connect URLs use the original HTTPS scheme. Do not trust arbitrary
  forwarded headers.

## Prerequisites

- An Azure subscription and permission to create the resources used by the selected
  deployment flow.
- Azure CLI, `kubectl`, and either Bicep or Terraform as described in the deployment
  guide.
- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0).
- Docker-compatible OCI tooling: Docker Engine or Podman. Docker Desktop is not
  required.
- A real, single-tenant Microsoft Entra **web application registration**.

### Microsoft Entra web application registration

Create the web app registration before deploying:

1. Configure it for one tenant and record its application (client) ID and tenant ID.
2. Register `https://<operator-host>/signin-oidc` as the web redirect URI and
   `https://<operator-host>/signout-callback-oidc` as the signed-out callback URL.
3. On the app registration, add a federated identity credential for the
   user-assigned managed identity used by the AKS workload:

   | Field | Value |
   |---|---|
   | Issuer | `https://login.microsoftonline.com/<tenant-id>/v2.0` |
   | Subject | Managed identity principal/object ID |
   | Audience | `api://AzureADTokenExchange` |

This app-registration credential is additional to the AKS OIDC federated credential
that binds the Kubernetes service account to the managed identity. They solve
different authentication hops.

`AzureAd:ClientId` is the **Entra web app client ID**. The service-account annotation
and `AzureAd:ClientCredentials:0:ManagedIdentityClientId` use the **workload managed
identity client ID**. Do not interchange them.

Production uses Microsoft.Identity.Web
`SignedAssertionFromManagedIdentity`, so no Entra client secret belongs in
Kubernetes manifests, Bicep, Terraform state, Key Vault, or another production
configuration surface.

## Local development

Use user-secrets for the local confidential-client credential:

```powershell
cd Application
dotnet user-secrets set "AzureAd:TenantId" "<tenant-id>"
dotnet user-secrets set "AzureAd:ClientId" "<entra-web-app-client-id>"
dotnet user-secrets set "AzureAd:ClientSecret" "<local-development-secret>"
dotnet user-secrets set "CosmosEndpoint" "https://<account>.documents.azure.com:443/"
dotnet run
```

The client secret is for local development only. The signed-in developer also needs
an Azure credential and the required Cosmos data-plane role.

Build and run the OCI image with either engine:

```powershell
cd Application
docker build -t todo:local .
docker run --rm -p 8080:8080 --env-file .env.local todo:local

# Podman equivalents
podman build -t todo:local .
podman run --rm -p 8080:8080 --env-file .env.local todo:local
```

Keep `.env.local` untracked and use it only for local configuration. For VS Code Dev
Containers backed by Podman, set
`"dev.containers.dockerPath": "podman"` in host/user settings. This repository does
not use Compose or a mounted host socket, so `dockerComposePath` and socket settings
are unnecessary unless that integration is added later.

## Build and test

```powershell
dotnet restore Application\todo.sln
dotnet build Application\todo.sln --configuration Release --no-restore
dotnet test Application\todo.sln --configuration Release --no-build
```

Choose a deployment flow:

- [Bicep](Bicep/README.md)
- [Terraform](Terraform/readme.md)
- [Azure Service Operator v2](ASO/README.md)
