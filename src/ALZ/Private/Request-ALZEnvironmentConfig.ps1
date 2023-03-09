
function Request-ALZEnvironmentConfig {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("bicep", "terraform")]
        [string] $alzIacProvider = "bicep"
    )
    <#
    .SYNOPSIS
    This function uses a template configuration to prompt for and return a user specified/modified configuration object.
    .EXAMPLE
    New-SlzEnvironmentConfig
    .EXAMPLE
    New-SlzEnvironmentConfig -sourceConfigurationFile "orchestration/scripts/parameters/sovereignLandingZone.parameters.json"
    .OUTPUTS
    System.Object. The resultant configuration values.
    #>
    if ($alzIacProvider -eq "terraform") {
        throw "Terraform is not yet supported."
    }

    $configuration = Initialize-ConfigurationObject -alzIacProvider $alzIacProvider
    Write-Verbose "Configuration object initialized."
    Write-Verbose "Configuration object: $(ConvertTo-Json $configuration)"

    foreach ($configurationValue in $configuration.PsObject.Properties) {
        Request-ConfigurationValue $configurationValue.Name $configurationValue.Value
    }

    return $configuration
}