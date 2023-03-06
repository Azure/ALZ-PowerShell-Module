
function Request-ALZEnvironmentConfig {
    param(
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
    $configuration = Initialize-ConfigurationObject
    Write-Verbose "Configuration object initialized."
    Write-Verbose "Configuration object: $(ConvertTo-Json $configuration)"

    foreach ($configurationValue in $configuration) {
        Request-ConfigurationValue $configurationValue
    }

    return $configuration
}