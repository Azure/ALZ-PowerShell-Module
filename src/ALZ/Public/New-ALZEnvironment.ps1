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
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment -alzEnvironmentDestination "."
    .EXAMPLE
    New-ALZEnvironment -alzEnvironmentDestination "." -alzBicepVersion "v0.13.0"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination = ".",

        [Parameter(Mandatory = $false)]
        [string] $alzBicepVersion = "v0.13.0"
    )

    Write-InformationColored "Getting ready to create a new ALZ environment with you..." -ForegroundColor Green  -InformationAction Continue

    $configuration = Request-ALZEnvironmentConfig

    if ($PSCmdlet.ShouldProcess("ALZ-Bicep module configuration", "modify")) {

        New-ALZDirectoryEnvironment -alzEnvironmentDestination $alzEnvironmentDestination | Out-Null
        $alzEnvironmentDestinationInternalCode = Join-Path $alzEnvironmentDestination "alz-bicep-internal" $alzBicepVersion

        $assetsDirectory = Join-Path $(Get-ScriptRoot) "../Assets"
        Copy-Item -Path "$assetsDirectory/*" -Recurse -Destination $alzEnvironmentDestination -Force

        $alzBicepSourceDirectory = Get-ALZBicepSource -alzBicepVersion $alzBicepVersion
        Copy-Item -Path "$alzBicepSourceDirectory/*" -Destination $alzEnvironmentDestinationInternalCode -Recurse -Force -Exclude @(".git", ".github", ".vscode", "docs", "tests", ".gitignore") | Out-Null

        Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination $alzEnvironmentDestination -configuration $configuration | Out-Null
    }

    return $true
}