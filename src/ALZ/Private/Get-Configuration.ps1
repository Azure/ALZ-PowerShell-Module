function Get-Configuration {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("bicep", "terraform")]
        [string] $alzIacProvider = "bicep",

        [Parameter(Mandatory = $false)]
        [string] $alzEnvironmentDestination = ".",

        [Parameter(Mandatory = $false)]
        [string] $alzBicepVersion = "v0.13.0"
    )
    <#
    .SYNOPSIS
    This function uses a template configuration to prompt for and return a user specified/modified configuration object.
    .EXAMPLE
    Get-Configuration
    .EXAMPLE
    Get-Configuration -alzIacProvider "bicep"
    .OUTPUTS
    System.Object. The resultant configuration values.
    #>

    if ($alzIacProvider -eq "terraform") {
        throw "Terraform is not yet supported."
    }

    $uxConfigurationFile = Join-Path $alzEnvironmentDestination "alz-bicep-config" "$alzBicepVersion.ux.config.json"
    return Get-Content -Path $uxConfigurationFile -Raw | ConvertFrom-Json
}

