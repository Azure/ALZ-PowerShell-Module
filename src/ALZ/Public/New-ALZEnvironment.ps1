function New-ALZEnvironment {
    <#
    .SYNOPSIS
    This function prompts a user for configuration values and modifies the ALZ Bicep configuration files accordingly.
    .DESCRIPTION
    This function will prompt the user for commonly used deployment configuration settings and modify the configuration in place.
    .PARAMETER alzBicepSource
    The directory containing the ALZ-Bicep source repo.
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment -alzBicepSource "../ALZ-Bicep"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $alzBicepSource = "../ALZ-Bicep"
    )

    $configuration = Request-ALZEnvironmentConfig

    if ($PSCmdlet.ShouldProcess("ALZ-Bicep module configuration", "modify")) {
        Edit-ALZConfigurationFilesInPlace -alzBicepRoot $alzBicepSource -configuration $configuration
    }

    return $configuration
}