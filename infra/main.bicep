targetScope = 'resourceGroup'

@allowed([
  'test'
  'prod'
])
param environment string

@description('Short lowercase prefix containing letters, digits, and hyphens.')
@minLength(2)
@maxLength(32)
param namePrefix string

param location string = resourceGroup().location
param appServicePlanSku string = 'F1'
param linuxFxVersion string = 'DOTNETCORE|10.0'

@description('Name of the Key Vault entry added manually after deployment. Its value is never created here.')
param keyVaultSecretName string = 'DemoValue'

@description('Single IPv4 CIDR to deny. Empty disables the rule.')
param blockedIpAddressCidr string = ''

@description('Email receiver for this environment action group.')
@minLength(3)
param alertEmail string

@minValue(1)
@maxValue(100)
param availabilityThresholdPercent int = 100

@allowed([
  60
  300
  600
  900
])
param availabilityFrequencySeconds int = 300

@minValue(1)
@maxValue(120)
param availabilityTimeoutSeconds int = 120

param availabilityLocations array = [
  { Id: 'us-fl-mia-edge' }
  { Id: 'emea-fr-pra-edge' }
  { Id: 'us-il-ch1-azr' }
  { Id: 'apac-sg-sin-azr' }
  { Id: 'us-ca-sjc-azr' }
]

var uniqueSuffix = take(uniqueString(subscription().subscriptionId, resourceGroup().id, environment, namePrefix), 8)
var compactPrefix = take(replace(toLower(namePrefix), '-', ''), 6)
var appServicePlanName = take(toLower('asp-${namePrefix}-${environment}-${uniqueSuffix}'), 40)
var webAppName = take(toLower('${namePrefix}-${environment}-${uniqueSuffix}'), 60)
var logAnalyticsName = take(toLower('log-${namePrefix}-${environment}-${uniqueSuffix}'), 63)
var applicationInsightsName = 'appi-${namePrefix}-${environment}-${uniqueSuffix}'
var keyVaultName = 'kv-${compactPrefix}-${environment}-${uniqueSuffix}'
var availabilityTestName = '${webAppName}-availability'
var actionGroupName = '${webAppName}-alerts'
var availabilityAlertName = '${webAppName}-unavailable'
var actionGroupShortName = environment == 'prod' ? 'prod-alert' : 'test-alert'
var keyVaultSecretsUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: appServicePlanSku
  }
  properties: {
    reserved: true
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 7
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      ipSecurityRestrictions: empty(blockedIpAddressCidr)
        ? []
        : [
            {
              name: 'BlockConfiguredClient'
              ipAddress: blockedIpAddressCidr
              action: 'Deny'
              priority: 100
              description: 'Environment-specific blocked client address'
            }
          ]
      ipSecurityRestrictionsDefaultAction: 'Allow'
      scmIpSecurityRestrictionsUseMain: false
    }
  }
}

resource keyVaultReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webApp.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource webAppSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: webApp
  name: 'appsettings'
  properties: {
    APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
    XDT_MicrosoftApplicationInsights_Mode: 'recommended'
    XDT_MicrosoftApplicationInsights_PreemptSdk: '1'
    KeyVaultDemo__Value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVaultSecretName})'
  }
  dependsOn: [
    keyVaultReaderRole
  ]
}

resource availabilityTest 'Microsoft.Insights/webtests@2022-06-15' = {
  name: availabilityTestName
  location: location
  kind: 'standard'
  tags: {
    'hidden-link:${applicationInsights.id}': 'Resource'
  }
  properties: {
    Name: availabilityTestName
    SyntheticMonitorId: availabilityTestName
    Kind: 'standard'
    Enabled: true
    Frequency: availabilityFrequencySeconds
    Timeout: availabilityTimeoutSeconds
    RetryEnabled: true
    Locations: availabilityLocations
    Request: {
      RequestUrl: 'https://${webApp.properties.defaultHostName}/'
      HttpVerb: 'GET'
      FollowRedirects: true
      ParseDependentRequests: false
    }
    ValidationRules: {
      ExpectedHttpStatusCode: 200
      IgnoreHttpStatusCode: false
      SSLCheck: true
      SSLCertRemainingLifetimeCheck: 7
    }
  }
}

resource alertActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [
      {
        name: '${environment}-email'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource availabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: availabilityAlertName
  location: 'global'
  properties: {
    description: 'Sends an email when the ${environment} application availability is below the configured threshold.'
    severity: 1
    enabled: true
    autoMitigate: true
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    scopes: [
      applicationInsights.id
    ]
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'AvailabilityBelowThreshold'
          metricNamespace: 'Microsoft.Insights/components'
          metricName: 'availabilityResults/availabilityPercentage'
          timeAggregation: 'Average'
          operator: 'LessThan'
          threshold: availabilityThresholdPercent
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'availabilityResult/name'
              operator: 'Include'
              values: [
                availabilityTestName
              ]
            }
          ]
        }
      ]
    }
    actions: [
      {
        actionGroupId: alertActionGroup.id
      }
    ]
  }
  dependsOn: [
    availabilityTest
  ]
}

output environment string = environment
output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output applicationInsightsName string = applicationInsights.name
output keyVaultName string = keyVault.name
output availabilityTestName string = availabilityTest.name
output availabilityAlertName string = availabilityAlert.name
output actionGroupName string = alertActionGroup.name
