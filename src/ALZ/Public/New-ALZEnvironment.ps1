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
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment -alzEnvironmentDestination "."
    .EXAMPLE
    New-ALZEnvironment -alzEnvironmentDestination "." -alzBicepVersion "v0.14.1-pre"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination = ".",

        [Parameter(Mandatory = $false)]
        [string] $alzBicepVersion = "v0.14.1-pre",

        [Parameter(Mandatory = $false)]
        [ValidateSet("bicep", "terraform")]
        [Alias("Iac")]
        [string] $alzIacProvider = "bicep"
    )

    Write-InformationColored "Getting ready to create a new ALZ environment with you..." -ForegroundColor Green  -InformationAction Continue

    if ($alzIacProvider -eq "terraform") {
        Write-InformationColored "Terraform is not yet supported." -ForegroundColor Red  -InformationAction Continue
        return
    }

    if ($PSCmdlet.ShouldProcess("ALZ-Bicep module configuration", "modify")) {

        $bicepConfig = Get-ALZBicepConfig -alzBicepVersion $alzBicepVersion

        New-ALZDirectoryEnvironment -alzEnvironmentDestination $alzEnvironmentDestination | Out-String | Write-Verbose

        $alzEnvironmentDestinationInternalCode = Join-Path $alzEnvironmentDestination "upstream-releases"
        Get-GithubRelease -directoryForReleases $alzEnvironmentDestinationInternalCode -githubRepoUrl $bicepConfig.module_url -releases @($bicepConfig.version) | Out-String | Write-Verbose
        Write-InformationColored "Copying ALZ-Bicep module to $alzEnvironmentDestinationInternalCode" -ForegroundColor Green  -InformationAction Continue
        Copy-ALZParametersFile -alzEnvironmentDestination $alzEnvironmentDestination -upstreamReleaseDirectory $(Join-Path $alzEnvironmentDestinationInternalCode  $bicepConfig.version) -configFiles $bicepConfig.config_files | Out-String | Write-Verbose
        Write-InformationColored "ALZ-Bicep source directory: $alzBicepSourceDirectory" -ForegroundColor Green  -InformationAction Continue

        $configuration = Request-ALZEnvironmentConfig -configurationParameters $bicepConfig.parameters

        Edit-ComputedConfiguration -configuration $configuration | Out-String | Write-Verbose
        Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination $alzEnvironmentDestination -configuration $configuration | Out-String | Write-Verbose
        Build-ALZDeploymentEnvFile -configuration $configuration -Destination $alzEnvironmentDestination | Out-String | Write-Verbose

        $isGitRepo = Test-ALZGitRepository -alzEnvironmentDestination $alzEnvironmentDestination
        if (-not $isGitRepo) {
            Write-InformationColored "The directory $alzEnvironmentDestination is not a git repository.  Please make it is a git repo after initialization." -ForegroundColor Red  -InformationAction Continue
        }
    }

    return
}