# Azure DevOps App Service Demo

A small ASP.NET Core MVC project for exploring Azure DevOps CI/CD, Bicep, App Service, and Key Vault.

Use it as a lightweight example of how one application can be built, tested, and deployed to separate test and production environments.

## What You Can Explore

- ASP.NET Core MVC on .NET 10
- Azure DevOps multi-stage YAML pipelines
- `develop` deployments to test
- `main` deployments to production
- Azure infrastructure created with Bicep
- App Service Key Vault references and managed identities
- Application Insights, availability tests, and alerts
- App Service IP restrictions
- Unit testing with xUnit

> This project is intended for learning and prototyping. Azure resources can generate costs, and the Key Vault value shown by the app must only contain a deliberately non-sensitive demonstration message.

## Project Structure

- `AzureDevOpsDemo.Web` - MVC application and Key Vault status page
- `AzureDevOpsDemo.Tests` - unit tests
- `infra` - shared Bicep template and environment parameter files
- `azure-pipelines.yml` - build, test, publish, and deployment pipeline
- `AzureDevOpsDemo.slnx` - solution file

## What You Need

- .NET 10 SDK
- Git
- An Azure subscription
- An Azure DevOps organization and project
- Azure CLI for local Bicep validation and `what-if`

## Run the App Locally

```powershell
dotnet restore .\AzureDevOpsDemo.slnx
dotnet run --project .\AzureDevOpsDemo.Web\AzureDevOpsDemo.Web.csproj
```

Without local configuration, the home page displays `Key Vault: Not connected`.

To try the connected state locally:

```powershell
$env:KeyVaultDemo__Value = "Hello from local development"
dotnet run --project .\AzureDevOpsDemo.Web\AzureDevOpsDemo.Web.csproj
```

Only use a non-sensitive test message.

## Run the Tests

```powershell
dotnet test .\AzureDevOpsDemo.slnx --configuration Release
```

The tests use in-memory configuration and do not contact Azure.

## Validate the Infrastructure

This command only compiles the Bicep template and can be run before any Azure resources exist:

```powershell
az bicep build --file .\infra\main.bicep
```

## How the Pipeline Works

```text
Build -> Test -> Publish -> Deploy
```

- A push to `develop` deploys only to test.
- A push to `main` deploys only to production.
- A failed build or test prevents deployment.
- Both environments use Linux App Service and `zipDeploy`.

Each environment receives its own App Service, Key Vault, monitoring, alerting, and IP restriction resources.

## Setup Overview

Use these names throughout the setup:

| Environment | Local branch | Azure resource group | User-assigned deployment identity | Azure DevOps service connection | Azure DevOps environment |
| --- | --- | --- | --- | --- | --- |
| Test | `develop` | `rg-azuredevopsdemo-test` | `id-azuredevopsdemo-test` | `azure-azuredevopsdemo-test` | `AzureDevOpsDemo-Test` |
| Production | `main` | `rg-azuredevopsdemo-prod` | `id-azuredevopsdemo-production` | `azure-azuredevopsdemo-production` | `AzureDevOpsDemo-Production` |

The production identity and service connection use `production` in their names, while the production resource group uses `prod`.

Each environment uses two managed identities:

- The **deployment identity** runs the pipeline. It can grant `Key Vault Secrets User` but does not read the secret.
- The **Web App identity** is created by Bicep. Bicep grants it `Key Vault Secrets User` so the app can read `DemoValue`.

### 1. In Azure DevOps

In the Azure DevOps web portal:

1. Create the Azure DevOps organization and project for this demo.
2. In that project, create an empty Azure Repo without a README or other initial commit.
3. Copy the new Azure Repo's clone URL.

Do not create the pipeline yet. The code and both branches must be pushed first.

### 2. On Your Local Computer

In this repository:

1. In `infra/main.test.bicepparam`, set `alertEmail` to the test alert recipient and `blockedIpAddressCidr` to the test client address to deny.
2. In `infra/main.prod.bicepparam`, set `alertEmail` to the production alert recipient and `blockedIpAddressCidr` to the production client address to deny.
   An empty `blockedIpAddressCidr` leaves the deny rule disabled until you configure an address for that environment.
3. Review and commit the project files, including both parameter files, on `main`.
4. Confirm that `main` and `develop` contain the setup changes you want to publish.
5. Add the empty Azure Repo as a Git remote named `azure`, using its clone URL.
6. Push `main` and `develop` to the `azure` remote.

Example commands:

```powershell
git remote add azure "<copied-azure-repos-url>"
git push -u azure main
git push -u azure develop
```

Verify existing branches, commits, and remotes before running these commands. Never force-push the initial publication.

### 3. In Azure Portal

Create the Azure resources and role assignments that must exist before the pipeline:

#### Test

1. Create resource group `rg-azuredevopsdemo-test`.
2. Create user-assigned managed identity `id-azuredevopsdemo-test` in `rg-azuredevopsdemo-test`.
3. Assign `Contributor` to `id-azuredevopsdemo-test`, scoped to `rg-azuredevopsdemo-test`.
4. Assign `Role Based Access Control Administrator` to `id-azuredevopsdemo-test` on `rg-azuredevopsdemo-test`. Add a condition that allows it to assign only `Key Vault Secrets User` to managed identities.
5. Assign `Key Vault Secrets Officer` on `rg-azuredevopsdemo-test` to the person who will add the test `DemoValue` secret.

#### Production

1. Create resource group `rg-azuredevopsdemo-prod`.
2. Create user-assigned managed identity `id-azuredevopsdemo-production` in `rg-azuredevopsdemo-prod`.
3. Assign `Contributor` to `id-azuredevopsdemo-production`, scoped to `rg-azuredevopsdemo-prod`.
4. Assign `Role Based Access Control Administrator` to `id-azuredevopsdemo-production` on `rg-azuredevopsdemo-prod`. Add a condition that allows it to assign only `Key Vault Secrets User` to managed identities.
5. Assign `Key Vault Secrets Officer` on `rg-azuredevopsdemo-prod` to the person who will add the production `DemoValue` secret.

### 4. Back on Your Local Computer

The resource groups now exist, so the Azure CLI can preview both deployments without changing Azure:

```powershell
az deployment group what-if --resource-group "rg-azuredevopsdemo-test" --parameters .\infra\main.test.bicepparam
az deployment group what-if --resource-group "rg-azuredevopsdemo-prod" --parameters .\infra\main.prod.bicepparam
```

Review the output before creating or running the pipeline.

### 5. Back in Azure DevOps

#### Test service connection

1. Open **Project settings > Service connections**.
2. Select **New service connection > Azure Resource Manager > Managed identity**.
3. Select managed identity `id-azuredevopsdemo-test` from resource group `rg-azuredevopsdemo-test`.
4. Set the Azure scope to `rg-azuredevopsdemo-test`.
5. Name the connection `azure-azuredevopsdemo-test`.
6. Leave **Grant access permission to all pipelines** cleared, then save the connection.

#### Production service connection

1. Open **Project settings > Service connections**.
2. Select **New service connection > Azure Resource Manager > Managed identity**.
3. Select managed identity `id-azuredevopsdemo-production` from resource group `rg-azuredevopsdemo-prod`.
4. Set the Azure scope to `rg-azuredevopsdemo-prod`.
5. Name the connection `azure-azuredevopsdemo-production`.
6. Leave **Grant access permission to all pipelines** cleared, then save the connection.

Next, create the deployment environments:

1. Open **Pipelines > Environments**.
2. Create `AzureDevOpsDemo-Test`.
3. Create `AzureDevOpsDemo-Production`.

Finally, create the pipeline:

1. Open **Pipelines > New pipeline** and select the Azure Repo created for this demo.
2. Select **Existing Azure Pipelines YAML file**.
3. Choose `/azure-pipelines.yml` and save the pipeline.

The service connections are the link between Azure DevOps and the managed identities in Azure. No client secret is required.

### 6. First Deployments

Deploy test first, then production. In each environment, the first run creates the Key Vault and its Web App reference. You add `DemoValue` after that run because Bicep does not create the secret. Use a non-sensitive message and never commit it to the repository.

#### Test

1. In **Azure DevOps > Pipelines**, run the pipeline on `develop`. If prompted for access to `azure-azuredevopsdemo-test`, select **View > Permit** for this pipeline only. Wait for `DeployTest` to succeed.
2. In **Azure Portal**, open the Key Vault in `rg-azuredevopsdemo-test`. Add a secret named `DemoValue` with a test message.
3. Run the pipeline on `develop` again. After `DeployTest` succeeds, open the test Web App and confirm its home page shows the test message.

#### Production

1. In **Azure DevOps > Pipelines**, run the pipeline on `main`. If prompted for access to `azure-azuredevopsdemo-production`, select **View > Permit** for this pipeline only. Wait for `DeployProduction` to succeed.
2. In **Azure Portal**, open the Key Vault in `rg-azuredevopsdemo-prod`. Add a secret named `DemoValue` with a production message.
3. Run the pipeline on `main` again. After `DeployProduction` succeeds, open the production Web App and confirm its home page shows the production message.
