
function Request-ALZEnvironmentConfig {
    param(
        [Parameter(Mandatory = $true)]
        [object] $configurationParameters
    )
    <#
    .SYNOPSIS
    This function uses a template configuration to prompt for and return a user specified/modified configuration object.
    .EXAMPLE
    Request-ALZEnvironmentConfig
    .EXAMPLE
    Request-ALZEnvironmentConfig -alzIacProvider "bicep"
    .OUTPUTS
    System.Object. The resultant configuration values.
    #>
    foreach ($configurationValue in $configurationParameters.PsObject.Properties) {
        if ($configurationValue.Value.Type -eq "UserInput") {
            Request-ConfigurationValue $configurationValue.Name $configurationValue.Value
        }
    }

    return $configurationParameters
}