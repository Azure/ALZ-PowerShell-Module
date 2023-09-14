
function Request-ALZEnvironmentConfig {
    param(
        [Parameter(Mandatory = $true)]
        [object] $configurationParameters,
        [Parameter(Mandatory = $false)]
        [switch] $respectOrdering
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

    $configurations = $configurationParameters.PsObject.Properties

    if($respectOrdering) {
        $configurations = $configurationParameters.PSObject.Properties | Sort-Object { $_.Value.Order }
    }

    foreach ($configurationValue in $configurations) {
        if ($configurationValue.Value.Type -eq "UserInput") {
            Request-ConfigurationValue $configurationValue.Name $configurationValue.Value
        }
    }

    return $configurationParameters
}