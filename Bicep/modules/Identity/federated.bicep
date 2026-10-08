param basename string
param issuerUrl string
param subject string

resource azidentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${basename}identity'
}

resource federatedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  name: 'aksfederatedidentity'
  parent: azidentity
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: issuerUrl
    subject: subject
  }
}
