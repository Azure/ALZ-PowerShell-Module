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
        $bootstrapModuleUrl = "https://github.com/Azure/accelerator-bootstrap-modules",

        [Parameter(Mandatory = $false, HelpMessage = "The bootstrap config file path.")]
        [string]
        $bootstrapConfigPath = ".config/ALZ-Powershell.config.json",

        [Parameter(Mandatory = $false, HelpMessage = "Bootstrap folder in teh source repo.")]
        [string]
        $bootstrapSourceFolder = ".",

        [Parameter(Mandatory = $false, HelpMessage = "Used to override the bootstrap folder location.")]
        [string]
        $bootstrapModuleOverrideFolderPath = "",

        [Parameter(Mandatory = $false, HelpMessage = "Used to override the starter folder location.")]
        [string]
        $starterModuleOverrideFolderPath = "",

        [Parameter(Mandatory = $false, HelpMessage = "Whether to use local mode for Bicep.")]
        [string]
        $bicepLegacyUrl = "https://github.com/Azure/ALZ-Bicep",

        [Parameter(Mandatory = $false, HelpMessage = "Whether to use legacy local mode for Bicep.")]
        [bool]
        $bicepLegacyMode = $true # Note this is set to true to act as a feature flag while the Bicep bootstrap is developed. It will be switched to false once it is all working.
    )

    Write-InformationColored "Getting ready to create a new ALZ environment with you..." -ForegroundColor Green -InformationAction Continue

    if ($PSCmdlet.ShouldProcess("Accelerator setup", "modify")) {

        $isLegacyBicep = $false
        if($alzIacProvider -eq "bicep") {
            $isLegacyBicep = $bicepLegacyMode -eq $true
        }

        $starterFolder = "starter"

        $starterModuleTargetFolder = $starterFolder
        if($alzIacProvider -eq "bicep") {
            if($isLegacyBicep) {
                $starterFolder = "."
            }
            $starterModuleTargetFolder = "$starterFolder/upstream-releases"
        }

        if(!$local) {
            Write-InformationColored "Checking you have the latest version of Terraform installed..." -ForegroundColor Green -InformationAction Continue
            $toolsPath = Join-Path -Path $targetDirectory -ChildPath ".tools"
            Get-TerraformTool -version "latest" -toolsPath $toolsPath
        }

        $bootstrapReleaseTag = "local"
        $bootstrapPath = $bootstrapModuleOverrideFolderPath

        if($bootstrapModuleOverrideFolderPath -eq "" && !$local) {
            $versionAndPath = New-FolderStructure `
                -targetDirectory $alzEnvironmentDestination `
                -url $bootstrapModuleUrl `
                -release "latest" `
                -targetFolder "bootstrap" `
                -sourceFolder $bootstrapSourceFolder

            $bootstapReleaseTag = $versionAndPath.releaseTag
            $bootstrapPath = $versionAndPath.path
        }

        # TODO Get config here



        $starterPath = $versionsAndPaths.starterPath

        if ($alzIacProvider -eq "bicep") {
            $starterPath = Join-Path $alzEnvironmentDestination $starterFolder
            New-ALZEnvironmentBicep `
                -targetDirectory $starterPath `
                -upstreamReleaseVersion $versionsAndPaths.starterReleaseTag `
                -upstreamReleaseFolderPath $versionsAndPaths.starterPath `
                -vcs $alzCicdPlatform `
                -local:$local
        }

        $starterPipelineFolder = "ci_cd"
        if($alzIacProvider -eq "bicep") {
            if($alzCicdPlatform -eq "azuredevops") {
                $starterPipelineFolder = ".azuredevops/pipelines"
            }
            if($alzCicdPlatform -eq "github") {
                $starterPipelineFolder = ".github/workflows"
            }
        }

        if(!$local) {
            New-Bootstrap `
                -bootstrapName $alzCicdPlatform `
                -bootstrapFolderPath $versionsAndPaths.bootstrapPath `
                -starterFolderPath $starterPath `
                -starterPipelineFolder $starterPipelineFolder `
                -userInputOverridePath $userInputOverridePath `
                -autoApprove:$autoApprove.IsPresent `
                -destroy:$destroy.IsPresent
        }
    }

    return
}