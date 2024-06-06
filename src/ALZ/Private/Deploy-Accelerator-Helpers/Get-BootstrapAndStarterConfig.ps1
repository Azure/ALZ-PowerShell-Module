
function Get-BootstrapAndStarterConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$iac,
        [Parameter(Mandatory = $false)]
        [string]$bootstrap,
        [Parameter(Mandatory = $false)]
        [string]$bootstrapPath,
        [Parameter(Mandatory = $false)]
        [string]$bootstrapConfigPath,
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$userInputOverrides
    )

    if ($PSCmdlet.ShouldProcess("Get Configuration for Bootstrap and Starter", "modify")) {
        $hasStarterModule = $false
        $starterModuleUrl = ""
        $starterModuleSourceFolder = ""
        $starterReleaseTag = ""
        $starterPipelineFolder = ""
        $starterReleaseArtefactName = ""
        $starterConfigFilePath = ""

        $bootstrapDetails = $null
        $validationConfig = $null
        $inputConfig = $null

        # Get the bootstap configuration
        $bootstrapConfigFullPath = Join-Path $bootstrapPath $bootstrapConfigPath
        Write-Verbose "Bootstrap config path $bootstrapConfigFullPath"
        $bootstrapConfig = Get-ALZConfig -configFilePath $bootstrapConfigFullPath
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
            throw
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
                throw
            }

            $starterModuleUrl = $starterModuleDetails.Value.$iac.url
            $starterModuleSourceFolder = $starterModuleDetails.Value.$iac.release_artefact_root_path
            $starterPipelineFolder = $starterModuleDetails.Value.$iac.release_artefact_ci_cd_path
            $starterReleaseArtefactName = $starterModuleDetails.Value.$iac.release_artefact_name
            $starterConfigFilePath = $starterModuleDetails.Value.$iac.release_artefact_config_file
        }

        # Get the bootstrap interface user input config
        $inputConfigFilePath = Join-Path -Path $bootstrapPath -ChildPath $bootstrapDetails.Value.interface_config_file
        Write-Verbose "Interface config path $inputConfigFilePath"
        $inputConfig = Get-ALZConfig -configFilePath $inputConfigFilePath

        return @{
            bootstrapDetails           = $bootstrapDetails
            hasStarterModule           = $hasStarterModule
            starterModuleUrl           = $starterModuleUrl
            starterModuleSourceFolder  = $starterModuleSourceFolder
            starterReleaseTag          = $starterReleaseTag
            starterPipelineFolder      = $starterPipelineFolder
            starterReleaseArtefactName = $starterReleaseArtefactName
            starterConfigFilePath      = $starterConfigFilePath
            validationConfig           = $validationConfig
            inputConfig                = $inputConfig
        }
    }
}
