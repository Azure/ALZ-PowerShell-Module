function New-ALZEnvironment {
    <#
    .SYNOPSIS
    Deploys an accelerator according to the supplied inputs.
    .DESCRIPTION
    This function is used to deploy accelerators consisting or bootstrap and optionally starter modules. The accelerators are designed to simplify and speed up configuration of common Microsoft patterns, such as CI / CD for Azure Landing Zones.
    .PARAMETER output
    The target directory for the accelerator artifacts. Depending on the choice and type of accelerlerator, this may be an intermediate stage or the final result of the accelerator.
    .PARAMETER iac
    The type of infrastructure as code that the accelerator implements. For example bicep or terraform.
    .PARAMETER bootstrap
    The accelerator bootstrap type to deploy.
    .PARAMETER alzIacProvider
    The IaC provider to use for the ALZ environment.
    .PARAMETER inputs
    A json or yaml file containing user input. This will cause the tool to by-pass requesting user input for the inputs supplied in the file. This is useful for automation or defining the inputs up front.
    .PARAMETER autoApprove
    Automatically approve the bootstrap deployment. This is useful for automation scenarios.
    .PARAMETER destroy
    Setting this will case the bootstrap to be destroyed. This is useful for cleaning up test environments.
    .EXAMPLE
    Deploy-Accelerator
    .EXAMPLE
    Deploy-Accelerator -o "."
    .EXAMPLE
    Deploy-Accelerator -o "." -i "bicep" -b "alz_github"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "The target directory for the accelerator output. Defaults to current folder.")]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [Alias("alzEnvironmentDestination")]
        [string] $targetDirectory = ".",

        [Parameter(Mandatory = $false, HelpMessage = "The specific bootstrap module release version to download. Defaults to latest.")]
        [string] $bootstrapRelease = "latest",

        [Parameter(Mandatory = $false, HelpMessage = "The specific starter module release version tom download. Defaults to latest.")]
        [Alias("alzBicepVersion")]
        [Alias("version")]
        [Alias("v")]
        [Alias("alzVersion")]
        [Alias("release")]
        [string] $starterRelease = "latest",

        [Parameter(Mandatory = $false, HelpMessage = "The infrastructure as code type to target. Supported options are 'bicep', 'terrform' or 'local'. You will be prompted to enter this if not supplied.")]
        [Alias("i")]
        [Alias("alzIacProvider")]
        [string] $iac = "",

        [Parameter(Mandatory = $false, HelpMessage = "The bootstrap module to deploy. You will be prompted to enter this if not supplied.")]
        [Alias("Cicd")]
        [Alias("c")]
        [Alias("alzCicdPlatform")]
        [Alias("b")]
        [string] $bootstrap = "",

        [Parameter(Mandatory = $false, HelpMessage = "The starter module to deploy. You will be prompted to enter this if not supplied.")]
        [string] $starter = "",

        [Parameter(Mandatory = $false, HelpMessage = "The inputs in json or yaml format. This is optional and used to automate or pre-prepare the accelerator inputs.")]
        [Alias("inputs")]
        [string] $inputConfigFilePath = "",

        [Parameter(Mandatory = $false, HelpMessage = "Determines whether to deploy the bootstrap without prompting for approval. This is used for automation.")]
        [switch] $autoApprove,

        [Parameter(Mandatory = $false, HelpMessage = "Determines that this run is to destroup the bootstrap. This is used to cleanup experiments.")]
        [switch] $destroy,

        [Parameter(Mandatory = $false, HelpMessage = "The bootstrap modules reposiotry url. This can be overridden for custom modules.")]
        [string]
        $bootstrapModuleUrl = "https://github.com/Azure/accelerator-bootstrap-modules",

        [Parameter(Mandatory = $false, HelpMessage = "The bootstrap modules release artifact name.")]
        [string]
        $bootstrapModuleReleaseArtifactName = "bootstrap_modules.zip",

        [Parameter(Mandatory = $false, HelpMessage = "The bootstrap config file path within the bootstrap module. This can be overridden for custom modules.")]
        [string]
        $bootstrapConfigPath = ".config/ALZ-Powershell.config.json",

        [Parameter(Mandatory = $false, HelpMessage = "The folder that containes the bootstrap modules in the bootstrap repo. This can be overridden for custom modules.")]
        [string]
        $bootstrapSourceFolder = ".",

        [Parameter(Mandatory = $false, HelpMessage = "Used to override the bootstrap folder location. This can be used to provide a folder locally in restricted environments.")]
        [string]
        $bootstrapModuleOverrideFolderPath = "",

        [Parameter(Mandatory = $false, HelpMessage = "Used to override the starter folder location. This can be used to provide a folder locally in restricted environments.")]
        [string]
        $starterModuleOverrideFolderPath = "",

        [Parameter(Mandatory = $false, HelpMessage = "Whether to skip checks that involve internet connection. The can allow running in restricted environments.")]
        [switch]
        $skipInternetChecks,

        [Parameter(Mandatory = $false, HelpMessage = "Whether to overwrite bootstrap and starter modules if they already exist. Warning, this may result in unexpected behaviour and should only be used for local development purposes.")]
        [switch]
        $replaceFiles,

        [Parameter(Mandatory = $false, HelpMessage = "An extra level of logging that is turned off by default for easier debugging.")]
        [switch]
        $writeVerboseLogs,

        [Parameter(Mandatory = $false, HelpMessage = "The path to the bootstrap terraform.tfvars file that you would like to replace the default one with. (e.g. c:\accelerator\terraform.tfvars). This file can also be in json format.")]
        [string]
        $bootstrapTfVarsOverridePath
    )

    $ProgressPreference = "SilentlyContinue"

    Write-InformationColored "Getting ready to deploy the accelerator with you..." -ForegroundColor Green -InformationAction Continue

    if ($PSCmdlet.ShouldProcess("Accelerator setup", "modify")) {
        # Get User Inputs from the -inputs file
        $inputConfig = $null

        if ($inputConfigFilePath -eq "") {
            $inputConfigFilePath = Request-SpecialInput -type "inputConfigFilePath" -inputConfig $inputConfig
        }

        $inputConfig = Get-ALZConfig -configFilePath $inputConfigFilePath

        # Get the IAC type if not specified
        if ($iac -eq "") {
            $iac = Request-SpecialInput -type "iac" -inputConfig $inputConfig
        }

        # Check and install Terraform CLI if needed
        $toolsPath = Join-Path -Path $targetDirectory -ChildPath ".tools"
        if($skipInternetChecks) {
            Write-InformationColored "Skipping Terraform tool check as you used the skipInternetCheck parameter. Please ensure you have the most recent version of Terraform installed" -ForegroundColor Yellow -InformationAction Continue
        } else {
            Write-InformationColored "Checking you have the latest version of Terraform installed..." -ForegroundColor Green -NewLineBefore -InformationAction Continue
            if ($iac -eq "bicep") {
                Write-InformationColored "Although you have selected Bicep, the Accelerator leverages the Terraform tool to bootstrap your Version Control System and Azure. This is will not impact your choice of Bicep post this initial bootstrap. Please refer to our documentation for further details..." -ForegroundColor Yellow -InformationAction Continue
            }
            Get-TerraformTool -version "latest" -toolsPath $toolsPath
            $hclParserToolPath = Get-HCLParserTool -toolVersion "v0.6.0" -toolsPath $toolsPath
        }

        # Download the bootstrap modules
        $bootstrapReleaseTag = ""
        $bootstrapPath = ""
        $bootstrapTargetFolder = "bootstrap"

        Write-InformationColored "Checking and Downloading the bootstrap module..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

        $versionAndPath = New-ModuleSetup `
            -targetDirectory $targetDirectory `
            -targetFolder $bootstrapTargetFolder `
            -sourceFolder $bootstrapSourceFolder `
            -url $bootstrapModuleUrl `
            -release $bootstrapRelease `
            -releaseArtifactName $bootstrapModuleReleaseArtifactName `
            -moduleOverrideFolderPath $bootstrapModuleOverrideFolderPath `
            -skipInternetChecks $skipInternetChecks `
            -replaceFile:$replaceFiles.IsPresent

        $bootstrapReleaseTag = $versionAndPath.releaseTag
        $bootstrapPath = $versionAndPath.path

        # Configure the starter module path
        $starterFolder = "starter"
        $starterModuleTargetFolder = $starterFolder

        # Setup the variables for bootstrap and starter modules
        $hasStarterModule = $false
        $starterModuleUrl = $bicepLegacyUrl
        $starterModuleSourceFolder = "."
        $starterReleaseArtifactName = ""
        $starterConfigFilePath = ""

        $bootstrapDetails = $null
        $validationConfig = $null
        $zonesSupport = $null

        $bootstrapAndStarterConfig = Get-BootstrapAndStarterConfig `
            -iac $iac `
            -bootstrap $bootstrap `
            -bootstrapPath $bootstrapPath `
            -bootstrapConfigPath $bootstrapConfigPath `
            -inputConfig $inputConfig `
            -toolsPath $toolsPath

        $bootstrapDetails = $bootstrapAndStarterConfig.bootstrapDetails
        $hasStarterModule = $bootstrapAndStarterConfig.hasStarterModule
        $starterModuleUrl = $bootstrapAndStarterConfig.starterModuleUrl
        $starterModuleSourceFolder = $bootstrapAndStarterConfig.starterModuleSourceFolder
        $starterReleaseArtifactName = $bootstrapAndStarterConfig.starterReleaseArtifactName
        $starterConfigFilePath = $bootstrapAndStarterConfig.starterConfigFilePath
        $validationConfig = $bootstrapAndStarterConfig.validationConfig
        $zonesSupport = $bootstrapAndStarterConfig.zonesSupport

        # Download the starter modules
        $starterReleaseTag = ""
        $starterConfig = $null

        if ($hasStarterModule) {
            Write-InformationColored "Checking and downloading the starter module..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

            $versionAndPath = New-ModuleSetup `
                -targetDirectory $targetDirectory `
                -targetFolder $starterModuleTargetFolder `
                -sourceFolder $starterModuleSourceFolder `
                -url $starterModuleUrl `
                -release $starterRelease `
                -releaseArtifactName $starterReleaseArtifactName `
                -moduleOverrideFolderPath $starterModuleOverrideFolderPath `
                -skipInternetChecks $skipInternetChecks `
                -replaceFile:$replaceFiles.IsPresent

            $starterReleaseTag = $versionAndPath.releaseTag
            $starterPath = $versionAndPath.path
            $starterConfig = Get-StarterConfig -starterPath $starterPath -starterConfigPath $starterConfigFilePath
        }

        # Set computed interface inputs
        $computedInputs = @{
            "iac_type"                       = $iac
            "on_demand_folder_repository"    = $starterModuleUrl
            "on_demand_folder_artifact_name" = $starterReleaseArtifactName
            "release_version"                = $starterReleaseTag -eq "local" ? $starterRelease : $starterReleaseTag
        }

        # Run the bootstrap
        $bootstrapTargetPath = Join-Path $targetDirectory $bootstrapTargetFolder
        $starterTargetPath = Join-Path $targetDirectory $starterFolder

        New-Bootstrap `
            -iac $iac `
            -bootstrapDetails $bootstrapDetails `
            -validationConfig $validationConfig `
            -inputConfig $inputConfig `
            -bootstrapTargetPath $bootstrapTargetPath `
            -bootstrapRelease $bootstrapReleaseTag `
            -hasStarter:$hasStarterModule `
            -starterTargetPath $starterTargetPath `
            -starterRelease $starterReleaseTag `
            -starterConfig $starterConfig `
            -autoApprove:$autoApprove.IsPresent `
            -destroy:$destroy.IsPresent `
            -starter $starter `
            -zonesSupport $zonesSupport `
            -computedInputs $computedInputs `
            -writeVerboseLogs:$writeVerboseLogs.IsPresent `
            -bootstrapTfVarsOverridePath $bootstrapTfVarsOverridePath `
            -hclParserToolPath $hclParserToolPath
    }

    $ProgressPreference = "Continue"

    return
}

New-Alias -Name "Deploy-Accelerator" -Value "New-ALZEnvironment"
