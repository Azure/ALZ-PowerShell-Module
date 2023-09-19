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

        $bicepConfig = Get-ALZConfig -alzVersion $alzVersion

        New-ALZDirectoryEnvironment -alzEnvironmentDestination $alzEnvironmentDestination -alzCicdDestination $alzCicdPlatform | Out-String | Write-Verbose

        $alzEnvironmentDestinationInternalCode = Join-Path $alzEnvironmentDestination "upstream-releases"

        Get-ALZGithubRelease -directoryForReleases $alzEnvironmentDestinationInternalCode -githubRepoUrl $bicepConfig.module_url -releases @($bicepConfig.version) | Out-String | Write-Verbose

        Write-InformationColored "Copying ALZ-Bicep module to $alzEnvironmentDestinationInternalCode" -ForegroundColor Green -InformationAction Continue
        Copy-ALZParametersFile -alzEnvironmentDestination $alzEnvironmentDestination -upstreamReleaseDirectory $(Join-Path $alzEnvironmentDestinationInternalCode $bicepConfig.version) -configFiles $bicepConfig.config_files | Out-String | Write-Verbose
        Copy-ALZParametersFile -alzEnvironmentDestination $alzEnvironmentDestination -upstreamReleaseDirectory $(Join-Path $alzEnvironmentDestinationInternalCode $bicepConfig.version) -configFiles $bicepConfig.cicd.$alzCicdPlatform | Out-String | Write-Verbose
        Write-InformationColored "ALZ-Bicep source directory: $alzBicepSourceDirectory" -ForegroundColor Green -InformationAction Continue

        $configuration = Request-ALZEnvironmentConfig -configurationParameters $bicepConfig.parameters

        Set-ComputedConfiguration -configuration $configuration | Out-String | Write-Verbose
        Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination $alzEnvironmentDestination -configuration $configuration | Out-String | Write-Verbose
        Build-ALZDeploymentEnvFile -configuration $configuration -Destination $alzEnvironmentDestination | Out-String | Write-Verbose

        $isGitRepo = Test-ALZGitRepository -alzEnvironmentDestination $alzEnvironmentDestination
        if (-not $isGitRepo) {
            Write-InformationColored "The directory $alzEnvironmentDestination is not a git repository.  Please make it is a git repo after initialization." -ForegroundColor Red -InformationAction Continue
        }
    }
}