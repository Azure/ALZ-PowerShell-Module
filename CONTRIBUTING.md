# Development

## Development Prerequisites

In order to develop this module you will need PowerShell 7.1 or later.

## Pre-requisites

```powershell
# Required to run Invoke-Build
Install-Module -F PSScriptAnalyzer
Install-Module -F InvokeBuild
Install-Module -F Pester
```

## Commands to build locally

```powershell
# Build and test locally
Remove-Module "ALZ" -Force
Invoke-Build -File .\src\ALZ.build.ps1
```

## Commands to import a build locally

```powershell
# Install the module locally
Invoke-Build -File .\src\ALZ.build.ps1
Import-Module .\src\Artifacts\ALZ.psd1 -Force
```

## How to do end to end local development with the bootstrap and starter modules

You can use the parameters `bootstrapModuleOverrideFolderPath` and `starterModuleOverrideFolderPath` to point to your local development folders. This will allow to make changes to all three modules locally and test them together without the need to commit the changes and push.

The following section provides an example folder structure and scripts to set up the local development environment and run the accelerator.

Example folder structure:

```plaintext
🖥️/
┗ 📂dev
  ┣ 📂code
  ┃ ┣ 📂accelerator-bootstrap-modules  # https://github.com/Azure/accelerator-bootstrap-modules
  ┃ ┣ 📂ALZ-Bicep                      # https://github.com/Azure/ALZ-Bicep
  ┃ ┣ 📂ALZ-PowerShell-Module          # https://github.com/Azure/ALZ-PowerShell-Module
  ┃ ┗ 📂alz-terraform-accelerator      # https://github.com/Azure/alz-terraform-accelerator
  ┗ 📂acc
      ┣ 📂bicep
      ┃ ┣ 📂config
      ┃ ┃ ┣ 📜inputs-azure-devops.yaml
      ┃ ┃ ┣ 📜inputs-github.yaml
      ┃ ┃ ┗ 📜inputs-local.yaml
      ┃ ┗ 📂output
      ┃   ┣ 📂azuredevops
      ┃   ┣ 📂github
      ┃   ┗ 📂local
      ┗ 📂terraform
        ┣ 📂config
        ┃ ┣ 📜inputs-azure-devops.yaml
        ┃ ┣ 📜inputs-github.yaml
        ┃ ┗ 📜inputs-local.yaml
        ┗ 📂output
          ┣ 📂azuredevops
          ┣ 📂github
          ┗ 📂local
```

Example folder structure script:

```pwsh
$targetFolder = "dev"
cd /
mkdir "$targetFolder/code"

$bicepConfigFolder = "$targetFolder/acc/bicep/config"
mkdir "$bicepConfigFolder"
mkdir "$targetFolder/acc/bicep/output/azuredevops"
mkdir "$targetFolder/acc/bicep/output/github"
mkdir "$targetFolder/acc/bicep/output/local"

$terraformConfigFolder = "$targetFolder/acc/terraform/config"
mkdir "$terraformConfigFolder"
mkdir "$targetFolder/acc/terraform/output/azuredevops"
mkdir "$targetFolder/acc/terraform/output/github"
mkdir "$targetFolder/acc/terraform/output/local"

cd "$targetFolder/code"
git clone https://github.com/Azure/accelerator-bootstrap-modules
git clone https://github.com/Azure/ALZ-Bicep
git clone https://github.com/Azure/ALZ-PowerShell-Module
git clone https://github.com/Azure/alz-terraform-accelerator
cd /

$bootstrapConfigFolderTerraform = "$targetFolder/code/alz-terraform-accelerator/templates/platform_landing_zone/examples/bootstrap"
Copy-Item -Path "$bootstrapConfigFolderTerraform/inputs-azure-devops.yaml" -Destination "$terraformConfigFolder/inputs-azure-devops.yaml" -Force
Copy-Item -Path "$bootstrapConfigFolderTerraform/inputs-github.yaml" -Destination "$terraformConfigFolder/inputs-github.yaml" -Force
Copy-Item -Path "$bootstrapConfigFolderTerraform/inputs-local.yaml" -Destination "$terraformConfigFolder/inputs-local.yaml" -Force

$bootstrapConfigFolderBicep = "$targetFolder/code/ALZ-Bicep/accelerator/examples/bootstrap"
Copy-Item -Path "$bootstrapConfigFolderBicep/inputs-azure-devop.yaml" -Destination "$bicepConfigFolder/inputs-azure-devops.yaml" -Force
Copy-Item -Path "$bootstrapConfigFolderBicep/inputs-github.yaml" -Destination "$bicepConfigFolder/inputs-github.yaml" -Force
Copy-Item -Path "$bootstrapConfigFolderBicep/inputs-local.yaml" -Destination "$bicepConfigFolder/inputs-local.yaml" -Force

```

>IMPORTANT! - Now you'll need to update the input files with your settings for VCS, etc.

Example scripts to run the accelerator:

### Bicep Azure DevOps

Run this from the VSCode terminal for the ALZ-PowerShell-Module repository:

>IMPORTANT! - Make sure to update the input file with your settings for VCS, etc.

```pwsh
Invoke-Build -File .\src\ALZ.build.ps1

$targetFolder = "dev"

# Uncomment to start fresh rather than relying on the -replaceFiles parameter
# Remove-Item -Path "/$targetFolder/acc/bicep/output/azuredevops" -Recurse -Force

Deploy-Accelerator `
    -bootstrapModuleOverrideFolderPath "/$targetFolder/code/accelerator-bootstrap-modules" `
    -starterModuleOverrideFolderPath "/$targetFolder/code/ALZ-Bicep" `
    -output "/$targetFolder/acc/bicep/output/azuredevops" `
    -inputs "/$targetFolder/acc/bicep/config/inputs-azure-devops.yaml" `
    -skipAlzModuleVersionRequirementsCheck `
    -verbose `
    -replaceFiles  # This will replace the files in the output folder with the files in the bootstrap and starter modules, so any updates are taken into account

```

### Bicep GitHub

Run this from the VSCode terminal for the ALZ-PowerShell-Module repository:

>IMPORTANT! - Make sure to update the input file with your settings for VCS, etc.

```pwsh
Invoke-Build -File .\src\ALZ.build.ps1

$targetFolder = "dev"

# Uncomment to start fresh rather than relying on the -replaceFiles parameter
# Remove-Item -Path "/$targetFolder/acc/bicep/output/github" -Recurse -Force

Deploy-Accelerator `
    -bootstrapModuleOverrideFolderPath "/$targetFolder/code/accelerator-bootstrap-modules" `
    -starterModuleOverrideFolderPath "/$targetFolder/code/ALZ-Bicep" `
    -output "/$targetFolder/acc/bicep/output/github" `
    -inputs "/$targetFolder/acc/bicep/config/inputs-github.yaml" `
    -skipAlzModuleVersionRequirementsCheck `
    -verbose `
    -replaceFiles  # This will replace the files in the output folder with the files in the bootstrap and starter modules, so any updates are taken into account

```

### Bicep Local

Run this from the VSCode terminal for the ALZ-PowerShell-Module repository:

>IMPORTANT! - Make sure to update the input file with your settings for VCS, etc.

```pwsh
Invoke-Build -File .\src\ALZ.build.ps1

$targetFolder = "dev"

# Uncomment to start fresh rather than relying on the -replaceFiles parameter
# Remove-Item -Path "/$targetFolder/acc/bicep/output/github" -Recurse -Force

Deploy-Accelerator `
    -bootstrapModuleOverrideFolderPath "/$targetFolder/code/accelerator-bootstrap-modules" `
    -starterModuleOverrideFolderPath "/$targetFolder/code/ALZ-Bicep" `
    -output "/$targetFolder/acc/bicep/output/local" `
    -inputs "/$targetFolder/acc/bicep/config/inputs-local.yaml" `
    -skipAlzModuleVersionRequirementsCheck `
    -verbose `
    -replaceFiles  # This will replace the files in the output folder with the files in the bootstrap and starter modules, so any updates are taken into account

```

### Terraform Azure DevOps

Run this from the VSCode terminal for the ALZ-PowerShell-Module repository:

>IMPORTANT! - Make sure to update the input file with your settings for VCS, etc.

```pwsh
Invoke-Build -File .\src\ALZ.build.ps1

$targetFolder = "dev"
$bootstrapConfigFolderTerraform = "$targetFolder/code/alz-terraform-accelerator/templates/platform_landing_zone/examples/full-multi-region"

# Uncomment to start fresh rather than relying on the -replaceFiles parameter
# Remove-Item -Path "/$targetFolder/acc/terraform/output/azuredevops" -Recurse -Force

Deploy-Accelerator `
    -bootstrapModuleOverrideFolderPath "/$targetFolder/code/accelerator-bootstrap-modules" `
    -starterModuleOverrideFolderPath "/$targetFolder/code/alz-terraform-accelerator/templates" `
    -output "/$targetFolder/acc/terraform/output/azuredevops" `
    -inputs "/$targetFolder/acc/terraform/config/inputs-azuredevops.yaml", "/$bootstrapConfigFolderTerraform/hub-and-spoke-vnet.tfvars" `
    -skipAlzModuleVersionRequirementsCheck `
    -verbose `
    -replaceFiles  # This will replace the files in the output folder with the files in the bootstrap and starter modules, so any updates are taken into account

```

>NOTE: The `config-hub-and-spoke-vnet-multi-region.yaml` file is an example. You can use any of the other configuration files.

### Terraform GitHub

Run this from the VSCode terminal for the ALZ-PowerShell-Module repository:

>IMPORTANT! - Make sure to update the input file with your settings for VCS, etc.

```pwsh
Invoke-Build -File .\src\ALZ.build.ps1

$targetFolder = "dev"
$bootstrapConfigFolderTerraform = "$targetFolder/code/alz-terraform-accelerator/templates/platform_landing_zone/examples/full-multi-region"

# Uncomment to start fresh rather than relying on the -replaceFiles parameter
# Remove-Item -Path "/$targetFolder/acc/terraform/output/github" -Recurse -Force

Deploy-Accelerator `
    -bootstrapModuleOverrideFolderPath "/$targetFolder/code/accelerator-bootstrap-modules" `
    -starterModuleOverrideFolderPath "/$targetFolder/code/alz-terraform-accelerator/templates" `
    -output "/$targetFolder/acc/terraform/output/github" `
    -inputs "/$targetFolder/acc/terraform/config/inputs-github.yaml", "/$bootstrapConfigFolderTerraform/hub-and-spoke-vnet.tfvars" `
    -skipAlzModuleVersionRequirementsCheck `
    -verbose `
    -replaceFiles  # This will replace the files in the output folder with the files in the bootstrap and starter modules, so any updates are taken into account

```

>NOTE: The `config-hub-and-spoke-vnet-multi-region.yaml` file is an example. You can use any of the other configuration files.

### Terraform Local

Run this from the VSCode terminal for the ALZ-PowerShell-Module repository:

>IMPORTANT! - Make sure to update the input file with your settings for VCS, etc.

```pwsh
Invoke-Build -File .\src\ALZ.build.ps1

$targetFolder = "dev"
$bootstrapConfigFolderTerraform = "$targetFolder/code/alz-terraform-accelerator/templates/platform_landing_zone/examples/full-multi-region"

# Uncomment to start fresh rather than relying on the -replaceFiles parameter
# Remove-Item -Path "/$targetFolder/acc/terraform/output/azuredevops" -Recurse -Force

Deploy-Accelerator `
    -bootstrapModuleOverrideFolderPath "/$targetFolder/code/accelerator-bootstrap-modules" `
    -starterModuleOverrideFolderPath "/$targetFolder/code/alz-terraform-accelerator/templates" `
    -output "/$targetFolder/acc/terraform/output/local" `
    -inputs "/$targetFolder/acc/terraform/config/inputs-local.yaml", "/$bootstrapConfigFolderTerraform/hub-and-spoke-vnet.tfvars" `
    -skipAlzModuleVersionRequirementsCheck `
    -verbose `
    -replaceFiles  # This will replace the files in the output folder with the files in the bootstrap and starter modules, so any updates are taken into account

```

>NOTE: The `config-hub-and-spoke-vnet-multi-region.yaml` file is an example. You can use any of the other configuration files.
