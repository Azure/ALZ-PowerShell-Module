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
        [Alias("alzEnvironmentDestination")]
        [string] $targetDirectory = ".",

        [Parameter(Mandatory = $false)]
        [Alias("alzBicepVersion")]
        [Alias("version")]
        [Alias("v")]
        [Alias("alzVersion")]
        [string] $release = "latest",

        [Parameter(Mandatory = $false)]
        [Alias("i")]
        [Alias("alzIacProvider")]
        [string] $iac = "",

        [Parameter(Mandatory = $false)]
        [Alias("Cicd")]
        [Alias("c")]
        [Alias("alzCicdPlatform")]
        [Alias("b")]
        [string] $bootstrap = "",

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

        [Parameter(Mandatory = $false, HelpMessage = "Whether to skip checks that involve internet connection")]
        [switch]
        $skipInternetChecks,

        [Parameter(Mandatory = $false, HelpMessage = "Whether to use legacy local mode for Bicep.")]
        [bool]
        $bicepLegacyMode = $true # Note this is set to true to act as a feature flag while the Bicep bootstrap is developed. It will be switched to false once it is all working.
    )

    $ProgressPreference = "SilentlyContinue"

    Write-InformationColored "Getting ready to create a new ALZ environment with you..." -ForegroundColor Green -InformationAction Continue

    if ($PSCmdlet.ShouldProcess("Accelerator setup", "modify")) {
        # Get User Inputs from the -inputs file
        $userInputOverrides = $null
        if($userInputOverridePath -ne "") {
            $userInputOverrides = Get-ALZConfig -configFilePath $userInputOverridePath
        }

        # Get the IAC type if not specified
        if($iac -eq "") {
            $iac = Request-SpecialInput -type "iac" -userInputOverrides $userInputOverrides
        }

        # Setup the Bicep flag
        $isLegacyBicep = $false
        if($iac -eq "bicep") {
            $isLegacyBicep = $bicepLegacyMode -eq $true
        }

        if($isLegacyBicep) {
            Write-Verbose "We are running in legacy Bicep mode"
        }

        if(!$isLegacyBicep){
            Write-Verbose "We are running in modern mode"
        }

        # Check and install Terraform CLI if needed
        if(!$isLegacyBicep) {
            if($skipInternetChecks) {
                Write-InformationColored "Skipping Terraform tool check as you used the skipInternetCheck parameter. Please ensure you have the most recent version of Terraform installed" -ForegroundColor Yellow -InformationAction Continue
            } else {
                Write-InformationColored "Checking you have the latest version of Terraform installed..." -ForegroundColor Green -InformationAction Continue
                $toolsPath = Join-Path -Path $targetDirectory -ChildPath ".tools"
                Get-TerraformTool -version "latest" -toolsPath $toolsPath
            }
        }

        # Download the bootstrap modules
        $bootstrapReleaseTag = "local"
        $bootstrapPath = $bootstrapModuleOverrideFolderPath
        $bootstrapTargetFolder = "bootstrap"

        if($bootstrapModuleOverrideFolderPath -eq "" -and !$isLegacyBicep) {
            $versionAndPath = $null

            if($skipInternetChecks) {
                $versionAndPath = Get-ExistingLocalRelease -targetDirectory $targetDirectory -targetFolder $bootstrapTargetFolder
            } else {
                $versionAndPath = New-FolderStructure `
                    -targetDirectory $targetDirectory `
                    -url $bootstrapModuleUrl `
                    -release "latest" `
                    -targetFolder $bootstrapTargetFolder `
                    -sourceFolder $bootstrapSourceFolder
            }
            $bootstrapReleaseTag = $versionAndPath.releaseTag
            $bootstrapPath = $versionAndPath.path
        }

        # Configure the starter module path
        $starterFolder = "starter"

        $starterModuleTargetFolder = $starterFolder
        if($iac -eq "bicep") {
            if($isLegacyBicep) {
                $starterFolder = "."
            }
            $starterModuleTargetFolder = "$starterFolder/upstream-releases"
        }

        # Setup the variables for bootstrap and starter modules
        $hasStarterModule = $false
        $starterModuleUrl = $bicepLegacyUrl
        $starterModuleSourceFolder = "."
        $starterReleaseTag = "local"
        $starterPipelineFolder = "local"

        $bootstrapDetails = $null
        $validationConfig = $null
        $inputConfig = $null

        if(!$isLegacyBicep) {
            # Get the bootstap configuration
            $bootstrapConfigPath = Join-Path $bootstrapPath $bootstrapConfigPath
            $bootstrapConfig = Get-ALZConfig -configFilePath $bootstrapConfigPath
            $validationConfig = $bootstrapConfig.validators

            # Get the available bootstrap modules
            $bootstrapModules = $bootstrapConfig.bootstrap_modules

            # Request the bootstrap type if not already specified
            if($bootstrap -eq "") {
                $bootstrap = Request-SpecialInput -type "bootstrap" -bootstrapModules $bootstrapModules -userInputOverrides $userInputOverrides
            }

            # Get the bootstrap details and validate it exists (use alias for legacy values)
            $bootstrapDetails = $bootstrapModules.PsObject.Properties | Where-Object { $_.Name -eq $bootstrap -or $bootstrap -in $_.Value.aliases }
            if($null -eq $bootstrapDetails) {
                Write-InformationColored "The bootstrap type '$bootstrap' that you have selected does not exist. Please try again with a valid bootstrap type..." -ForegroundColor Red -InformationAction Continue
                return
            }

            # Get the starter modules for the selected bootstrap if it has any
            $bootstrapStarterModule = $bootstrapDetails.Value.PSObject.Properties | Where-Object { $_.Name -eq  "starter_modules" }

            if($null -ne $bootstrapStarterModule) {
                # If the bootstrap has starter modules, get the details and url
                $hasStarterModule = $true
                $starterModules = $bootstrapConfig.PSObject.Properties | Where-Object { $_.Name -eq "starter_modules" }
                $starterModuleType = $bootstrapStarterModule.Value
                $starterModuleDetails = $starterModules.Value.PSObject.Properties | Where-Object { $_.Name -eq $starterModuleType }
                if($null -eq $starterModuleDetails) {
                    Write-InformationColored "The starter modules '$($starterModuleType)' for the bootstrap type '$bootstrap' that you have selected does not exist. This could be an issue with your custom configuration, please check and try again..." -ForegroundColor Red -InformationAction Continue
                    return
                }

                $starterModuleUrl = $starterModuleDetails.Value.$iac.url
                $starterModuleSourceFolder = $starterModuleDetails.Value.$iac.module_path
                $starterPipelineFolder = $starterModuleDetails.Value.$iac.pipeline_folder
            }

            # Get the bootstrap interface user input config
            $inputConfigFilePath = Join-Path -Path $bootstrapPath -ChildPath $bootstrapDetails.Value.interface_config_file
            Write-Verbose "Interface config path $inputConfigFilePath"
            $inputConfig = Get-ALZConfig -configFilePath $inputConfigFilePath
        }

        # Download the starter modules
        $starterReleaseTag = "local"
        $starterPath = $starterModuleOverrideFolderPath

        if($starterModuleOverrideFolderPath -eq "" -and ($hasStarterModule -or $isLegacyBicep)) {
            $versionAndPath = $null

            if($skipInternetChecks) {
                $versionAndPath = Get-ExistingLocalRelease -targetDirectory $targetDirectory -targetFolder $starterModuleTargetFolder
            } else {
                $versionAndPath = New-FolderStructure `
                    -targetDirectory $targetDirectory `
                    -url $starterModuleUrl `
                    -release $release `
                    -targetFolder $starterModuleTargetFolder `
                    -sourceFolder $starterModuleSourceFolder
            }

            $starterReleaseTag = $versionAndPath.releaseTag
            $starterPath = $versionAndPath.path
        }

        # Run the bicep parameter setup if the iac is Bicep
        if ($iac -eq "bicep") {
            $targetPath = Join-Path $targetDirectory $starterFolder
            New-ALZEnvironmentBicep `
                -targetDirectory $targetPath `
                -upstreamReleaseVersion $starterReleaseTag `
                -upstreamReleaseFolderPath $starterPath `
                -vcs $bootstrap `
                -local:$isLegacyBicep
        }

        # Run the bootstrap
        if(!$isLegacyBicep) {
            $bootstrapTargetPath = Join-Path $targetDirectory $bootstrapTargetFolder
            $starterTargetPath = Join-Path $targetDirectory $starterFolder

            New-Bootstrap `
                -iac $iac `
                -bootstrapDetails $bootstrapDetails `
                -validationConfig $validationConfig `
                -inputConfig $inputConfig `
                -bootstrapTargetPath $bootstrapTargetPath `
                -bootstrapPath $bootstrapPath `
                -bootstrapRelease $bootstrapReleaseTag `
                -hasStarter:$hasStarterModule `
                -starterTargetPath $starterTargetPath `
                -starterPath $starterPath `
                -starterPipelineFolder $starterPipelineFolder `
                -starterRelease $starterReleaseTag `
                -userInputOverrides $userInputOverrides `
                -autoApprove:$autoApprove.IsPresent `
                -destroy:$destroy.IsPresent
        }
    }

    $ProgressPreference = "Continue"

    return
}

New-Alias -Name "Deploy-Accelerator" -Value "New-ALZEnvironment"
