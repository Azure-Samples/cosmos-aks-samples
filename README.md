# Cosmos DB sample ToDo App on AKS Cluster

A Web reference ASP.NET Core MVC application that demonstrates how to use the Microsoft Azure Cosmos DB service to store and access data. The application is designed to be deployed on Azure Kubernetes Services(AKS) using [Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview?tabs=bicep) and [Azure Service Operators(ASO)](https://devblogs.microsoft.com/cse/2021/11/11/azure-service-operators-a-kubernetes-native-way-of-deploying-azure-resources/)


## Prerequisites

Before you can run this sample, you must have the following prerequisites:
* An Azure Subscription - If you don't have an account, [Sign up for a free trial](https://azure.microsoft.com/en-us/free/).
* Clone this repository or download the zip file.
* [Docker Desktop](https://docs.docker.com/desktop/)
* [Visual Studio 2022](https://visualstudio.microsoft.com/downloads) with the Web Development, Azure Tools workload, and/or .NET Core cross-platform development workload installed
* [.NET Core Development Tools](https://dotnet.microsoft.com/download/dotnet-core/) for development with .NET Core

## Overview

This sample shows you how to use the Microsoft Azure Cosmos DB service to store and access data from an ASP.NET Core MVC application. This application uses Managed Identity and Cosmos RBAC. The application is published as a docker container and can be hosted on Azure Kubernetes Services (AKS).

This sample can be deployed using the following two methods:

* Bicep template: This sample uses Bicep template to deploy the AKS and other infrastructure resources (Resource Groups, VNet, Managed Identity, Key Vault, Azure Container Registry), and a Cosmos DB SQL account. It then deploys the the sample application on AKS using the Kubernetes command-line client, kubectl. This example uses Key Vault to store the application secrets.
* ASO deployment: This sample uses Bicep template only for deploying the the AKS infrastructure resources (Resource Groups, VNet, Managed Identity, ACR). It uses the Kubernetes command-line client, kubectl and Azure Service Operator (ASO) to deploy the Cosmos DB SQL account and host the sample application on AKS. This example doesn’t use Key Vault.

## Running the sample 
To run this sample, follow the instructions in the ASO or Bicep folder. The steps provided will deploy the Azure resources and Cosmos DB account. It will also host the sample ToDo application on AKS.