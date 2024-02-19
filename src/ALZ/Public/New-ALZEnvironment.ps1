function New-ALZEnvironment {
    <#
    .SYNOPSIS
    This function prompts a user for configuration values and modifies the ALZ Bicep configuration files accordingly.
    .DESCRIPTION
    This function will prompt the user for commonly used deployment configuration settings and modify the configuration in place.
    .PARAMETER alzBicepSource
    The directory containing the ALZ-Bicep source repo.
    .PARAMETER alzEnvironmentDestination
    The directory where the ALZ environment will be created.
    .PARAMETER alzBicepVersion
    The version of the ALZ-Bicep module to use.
    .PARAMETER alzIacProvider
    The IaC provider to use for the ALZ environment.
    .PARAMETER userInputOverridePath
    A json file containing user input overrides for the user input prompts. This will cause the tool to by pass requesting user input for that field and use the value(s) provided. E.g { "starter_module": "basic", "azure_location": "uksouth" }
    .PARAMETER autoApprove
    Automatically approve the terraform apply.
    .PARAMETER destroy
    Destroy the terraform environment.
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment -alzEnvironmentDestination "."
    .EXAMPLE
    New-ALZEnvironment -alzEnvironmentDestination "." -alzBicepVersion "v0.16.4"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination = ".",

        [Parameter(Mandatory = $false)]
        [Alias("alzBicepVersion")]
        [Alias("version")]
        [Alias("v")]
        [string] $alzVersion = "latest",

        [Parameter(Mandatory = $false)]
        [ValidateSet("bicep", "terraform")]
        [Alias("Iac")]
        [Alias("i")]
        [string] $alzIacProvider = "bicep",

        [Parameter(Mandatory = $false)]
        [Alias("Cicd")]
        [Alias("c")]
        [string] $alzCicdPlatform = "github",

        [Parameter(Mandatory = $false)]
        [Alias("inputs")]
        [string] $userInputOverridePath = "",

        [Parameter(Mandatory = $false)]
        [switch] $autoApprove,

        [Parameter(Mandatory = $false)]
        [switch] $destroy,

        [Parameter(Mandatory = $false, HelpMessage = "The bootstrap modules reposiotry url.")]
        [string]
        $bootstrapModuleUrl = "https://github.com/Azure/ALZ-PowerShell-Module",

        [Parameter(Mandatory = $false, HelpMessage = "The terraform starter modules repository url.")]
        [string]
        $terraformModuleUrl = "https://github.com/Azure/alz-terraform-accelerator",

        [Parameter(Mandatory = $false, HelpMessage = "The bicep starter modules reposiotry url.")]
        [string]
        $bicepModuleUrl = "https://github.com/Azure/ALZ-Bicep",

        [Parameter(Mandatory = $false, HelpMessage = "The directory location of the bootstrap modules.")]
        [string]
        $bootstrapModuleSourceFolder = "bootstrap",

        [Parameter(Mandatory = $false, HelpMessage = "The directory location of the starter modules.")]
        [string]
        $starterModuleSourceFolder = "",

        [Parameter(Mandatory = $false, HelpMessage = "Used to override the bootstrap folder location.")]
        [string]
        $bootstrapModuleOverrideFolderPath = "",

        [Parameter(Mandatory = $false, HelpMessage = "Used to override the starter folder location.")]
        [string]
        $starterModuleOverrideFolderPath = ""
    )

    Write-InformationColored "Getting ready to create a new ALZ environment with you..." -ForegroundColor Green -InformationAction Continue

    if ($PSCmdlet.ShouldProcess("Accelerator setup", "modify")) {
        if($starterModuleSourceFolder -eq "") {
            if($alzIacProvider -eq "bicep") {
                $starterModuleSourceFolder = "."
            }
            if($alzIacProvider -eq "terraform") {
                $starterModuleSourceFolder = "templates"
            }
        }

        $starterModuleTargetFolder = "starter"
        if($alzIacProvider -eq "bicep") {
            $starterModuleTargetFolder = "starter/upstream-releases"
        }

        if($alzIacProvider -eq "bicep") {
            $starterUrl = $bicepModuleUrl
        }
        if($alzIacProvider -eq "terraform") {
            $starterUrl = $terraformModuleUrl
        }

        $versions = New-FolderStructure -targetDirectory $alzEnvironmentDestination -bootstrapModuleSourceFolder $bootstrapModuleSourceFolder -starterModuleSourceFolder $starterModuleSourceFolder -bootstrapUrl $bootstrapModuleUrl -starterUrl $starterUrl -bootstrapVersion "latest" -starterVersion $alzVersion -starterTargetFolder $starterModuleTargetFolder -bootstrapModuleOverrideFolderPath $bootstrapModuleOverrideFolderPath -starterModuleOverrideFolderPath $starterModuleOverrideFolderPath

        Write-InformationColored $versions -ForegroundColor Green -InformationAction Continue

        if ($alzIacProvider -eq "bicep") {
            return
            New-ALZEnvironmentBicep -alzEnvironmentDestination $alzEnvironmentDestination -alzVersion $alzVersion -alzCicdPlatform $alzCicdPlatform
        }

        if($alzIacProvider -eq "terraform") {
            return
            New-ALZEnvironmentTerraform -alzEnvironmentDestination $alzEnvironmentDestination -alzVersion $alzVersion -alzCicdPlatform $alzCicdPlatform -userInputOverridePath $userInputOverridePath -autoApprove:$autoApprove.IsPresent -destroy:$destroy.IsPresent
        }
    }

    return
}