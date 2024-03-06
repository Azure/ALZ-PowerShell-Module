function New-ALZEnvironmentBicep {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination,

        [Parameter(Mandatory = $false)]
        [string] $alzVersion,

        [Parameter(Mandatory = $false)]
        [ValidateSet("github", "azuredevops")]
        [Alias("Cicd")]
        [string] $alzCicdPlatform
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Bicep module configuration", "modify")) {

        if($alzVersion -ne "latest" -and $alzVersion -notlike "*-preview") {
            $lastSupportedLocalVersion = [System.Version]"0.16.5"
            $targetVersion = [System.Version]($alzVersion -replace "v", "")

            if($targetVersion -le $lastSupportedLocalVersion) {
                throw "The version of the ALZ-Bicep accelerator you are targetting is not supported by this version of the ALZ PowerShell module. In order to target versions prior to v0.16.6 you will need to downgrade to version v0.2.20 or lower of this module."
            }
        }

        New-ALZDirectoryEnvironment -alzEnvironmentDestination $alzEnvironmentDestination -alzCicdDestination $alzCicdPlatform | Out-String | Write-Verbose

        $alzEnvironmentDestinationInternalCode = Join-Path $alzEnvironmentDestination "upstream-releases"

        # Downloading the latest or specified version of the bicep accelerator module
        $releaseTag = Get-ALZGithubRelease -directoryForReleases $alzEnvironmentDestination -iac "bicep" -release $alzVersion
        $releasePath = Join-Path -Path $alzEnvironmentDestinationInternalCode -ChildPath $releaseTag

        # Getting the configuration
        $configFilePath = Join-Path -Path $releasePath -ChildPath "accelerator/.config/ALZ-Powershell.config.json"
        $bicepConfig = Get-ALZConfig -configFilePath $configFilePath

        Write-InformationColored "Copying ALZ-Bicep module to $alzEnvironmentDestinationInternalCode" -ForegroundColor Green -InformationAction Continue
        Copy-ALZParametersFile -alzEnvironmentDestination $alzEnvironmentDestination -upstreamReleaseDirectory $(Join-Path $alzEnvironmentDestinationInternalCode $releaseTag) -configFiles $bicepConfig.config_files | Out-String | Write-Verbose
        Copy-ALZParametersFile -alzEnvironmentDestination $alzEnvironmentDestination -upstreamReleaseDirectory $(Join-Path $alzEnvironmentDestinationInternalCode $releaseTag) -configFiles $bicepConfig.cicd.$alzCicdPlatform | Out-String | Write-Verbose
        Write-InformationColored "ALZ-Bicep source directory: $alzBicepSourceDirectory" -ForegroundColor Green -InformationAction Continue

        $configuration = Request-ALZEnvironmentConfig -configurationParameters $bicepConfig.parameters

        Set-ComputedConfiguration -configuration $configuration | Out-String | Write-Verbose
        Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination $alzEnvironmentDestination -configuration $configuration | Out-String | Write-Verbose
        Build-ALZDeploymentEnvFile -configuration $configuration -Destination $alzEnvironmentDestination -version $releaseTag | Out-String | Write-Verbose
        Add-AvailabilityZonesBicepParameter -alzEnvironmentDestination $alzEnvironmentDestination -configFile $bicepConfig| Out-String | Write-Verbose

        $isGitRepo = Test-ALZGitRepository -alzEnvironmentDestination $alzEnvironmentDestination
        if (-not $isGitRepo) {
            Write-InformationColored "The directory $alzEnvironmentDestination is not a git repository.  Please make it is a git repo after initialization." -ForegroundColor Red -InformationAction Continue
        }
    }
}