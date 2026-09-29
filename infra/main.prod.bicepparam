using 'main.bicep'

param environment = 'prod'
param namePrefix = 'azuredevopsdemo'
param location = 'swedencentral'
param appServicePlanSku = 'F1'
param linuxFxVersion = 'DOTNETCORE|10.0'
param keyVaultSecretName = 'DemoValue'
param alertEmail = 'azuredevopsdemo-alerts@example.com' // Replace with the production alert recipient before deployment.
param blockedIpAddressCidr = '' // Set to the intended production client CIDR to enable the deny rule.
