# Azure Landing Zones Accelerators for Bicep and Terraform

[![license](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/Azure/ALZ-PowerShell-Module/badge)](https://scorecard.dev/viewer/?uri=github.com/Azure/ALZ-PowerShell-Module)
![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/Azure/ALZ-PowerShell-Module?style=flat&logo=github)
![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed/Azure/ALZ-PowerShell-Module)
![GitHub contributors](https://img.shields.io/github/contributors/Azure/ALZ-PowerShell-Module)

![Logo](./docs/wiki/media/Logo.png)

## Introduction

TLDR: Head straight over to our [Quick Start](https://github.com/Azure/ALZ-PowerShell-Module/wiki/%5BUser-Guide%5D-Quick-Start) to get going now.

This repository contains the PowerShell module and documentation for the Azure landing zones Accelerators for Bicep and Terraform. The accelerators are an opinionated implementation of the Azure Landing Zones Terraform modules, with Azure DevOps or GitHub bootstrapping.

It is designed to be used as a template to enable you to get started quickly deploying ALZ with Bicep or Terraform.

Please refer to our [Wiki](https://github.com/Azure/ALZ-PowerShell-Module/wiki) for detailed features and usage instructions.

## Quick Start

To get going right now, run these PowerShell steps:

```pwsh
Install-Module -Name ALZ
Deploy-Accelerator
```

## More Examples

Here are more examples with different options:

### Azure Landing Zone Environment with Bicep and GitHub Actions Workflows

```powershell
Deploy-Accelerator -o <output_directory> -i "bicep" -b "alz_github"
```

### Azure Landing Zone Environment with Bicep and Azure DevOps Pipelines

```powershell
Deploy-Accelerator -o <output_directory> -i "bicep" -b "alz_azuredevops"
```

### Azure Landing Zone Environment with Terraform and GitHub Pipelines

```powershell
Deploy-Accelerator -o <output_directory> -i "terraform" -b "alz_github"
```

### Azure Landing Zone Environment with Terraform and Azure DevOps Pipelines

```powershell
Deploy-Accelerator -o <output_directory> -i "terraform" -b "alz_azuredevops"
```

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit [https://cla.opensource.microsoft.com](https://cla.opensource.microsoft.com).

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
