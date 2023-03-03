function New-ALZEnvironment {
    <#
    .SYNOPSIS
    This function creates an Slz deployment configuration and directory structure.
    .DESCRIPTION
    This function will, using an optionally specified template configuration file, prompt the user for mandatory values and
     create a new configuration file using those specified values.
    It will then will create a local copy of the deployment scripts to allow that deployment to proceed.
    .PARAMETER destinationDirectory
    The directory to create the new configuration and deployment scripts in.  Defaults to the current directory.
    .EXAMPLE
    New-SlzEnvironment
    .EXAMPLE
    New-SlzEnvironment -destinationDirectory "C:\Users\me\myNewEnvironment"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Output")]
        [string] $destinationDirectory = "./",

        [Parameter(Mandatory = $false)]
        [string] $alzBicepSource = "../ALZ-Bicep"
    )

    if ($pscmdlet.ShouldProcess($destinationDirectory)) {
        $configuration = $newConfigDirectory = New-ALZEnvironmentConfig -destinationDirectory $destinationDirectory
        Update-ALZBicepConfigurationFiles -alzBicepRoot $alzBicepSource -configuration $configuration
    }

    return $newConfigDirectory
}