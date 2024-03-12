# ALZ / Accelerator PowerShell Module

[![license](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

![Logo](./docs/ALZLogo.png)

## Synopsis

This is a PowerShell module that provides a set of cmdlets to create and manage Accelerators for Azure Landing Zones and other workloads.

## Description

This module provides a set of cmdlets to create and manage Accelerators for Azure Landing Zones and other workloads.

## Why

The goal of this project it is to make easy to get started with Azure Landing Zones and other workloads. It is designed to speed up some basic tasks that you would need to perform whilst managing your Azure Landing Zones.

## Getting Started

### Prerequisites

In order to use this module you will need PowerShell 7.1 or higher.
Download and install the latest version from the official PowerShell GitHub releases page: [PowerShell Releases](https://github.com/PowerShell/PowerShell/releases)

To make PowerShell 7 your default instead of version 5, consider setting an alias.

Open a PowerShell session and run the following command:

   ```powershell
   $PSVersionTable.PSVersion
   Set-Alias powershell pwsh
  ```

### Installation

You can install this module using PowerShellGet.

```powershell
Install-Module -Name ALZ
```

### Update

Whenever a new release from the module has been released, you can update it easily. The changelog can be found [here](/docs/CHANGELOG.md).

```powershell
# find out which version you have installed
PS C:\Users\you> Get-InstalledModule -Name ALZ

Version    Name                                Repository           Description
-------    ----                                ----------           -----------
0.2.6      ALZ                                 PSGallery            Azure Landing Zones Powershell Module

# update to the latest version
Update-Module -Name ALZ
```

### Quick start

Before you start you can utilize the functionality of the module to verify if you have all the prerequisites installed with the built in command.

#### Bicep

```powershell
Test-ALZRequirement -i "bicep"
```

Currently this tests for:

* Supported minimum PowerShell version (7.1)
* Supported minimum Az PowerShell module version (10.0.0)
* Git
* Azure CLI
* Bicep
* Visual Studio Code

#### Terraform

```powershell
Test-ALZRequirement -i "terraform"
```

This currently tests for:

* Supported minimum PowerShell version (7.1)
* Azure CLI

> NOTE: Terraform CLI is downloaded as part of the module if you don't already have the latest version.

#### Azure Landing Zone Environment with Bicep and GitHub Actions Workflows

```powershell
Deploy-Accelerator -o <output_directory> -i "bicep" -b "alz_github"
```

#### Azure Landing Zone Environment with Bicep and Azure DevOps Pipelines

```powershell
Deploy-Accelerator -o <output_directory> -i "bicep" -b "alz_azuredevops"
```

#### Azure Landing Zone Environment with Terraform and GitHub Pipelines

```powershell
Deploy-Accelerator -o <output_directory> -i "terraform" -b "alz_github"
```

#### Azure Landing Zone Environment with Terraform and Azure DevOps Pipelines

```powershell
Deploy-Accelerator -o <output_directory> -i "terraform" -b "alz_azuredevops"
```

## Development

### Development Prerequisites

In order to develop this module you will need PowerShell 7.1 or later.

### Pre-requisites

```powershell
# Required to run Invoke-Build
Install-Module -F PSScriptAnalyzer
Install-Module -F InvokeBuild
Install-Module -F Pester
```

### Commands to build locally

```powershell
# Build and test locally
Remove-Module "ALZ" -Force
Invoke-Build -File .\src\ALZ.build.ps1
```

### Commands to import a build locally

```powershell
# Install the module locally
Invoke-Build -File .\src\ALZ.build.ps1
Import-Module .\src\Artifacts\ALZ.psd1 -Force
```

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
