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

    $configuration = Request-ALZEnvironmentConfig

    $alzBicepSourceDirectory = Get-ALZBicepSource -alzBicepVersion $alzBicepVersion
    # Create destination file structure
    New-ALZDirectoryEnvironment -alzEnvironmentDestination $alzEnvironmentDestination -configuration $configuration | Out-Null

    Copy-ALZAssetFile -alzBicepRoot $alzBicepSourceDirectory -alzEnvironmentDestination $alzEnvironmentDestination | Out-Null

    if ($PSCmdlet.ShouldProcess("ALZ-Bicep module configuration", "modify")) {
        Edit-ALZConfigurationFilesInPlace -alzBicepRoot $alzBicepSourceDirectory -configuration $configuration | Out-Null
    }

    return $true
}