
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

    foreach ($configurationValue in $configuration) {
        Request-ConfigurationValue $configurationValue
    }

    return $configuration
}