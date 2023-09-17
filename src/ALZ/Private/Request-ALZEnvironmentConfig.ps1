
function Request-ALZEnvironmentConfig {
    param(
        [Parameter(Mandatory = $true)]
        [object] $configurationParameters,
        [Parameter(Mandatory = $false)]
        [switch] $respectOrdering,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $userInputOverrides = $null
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

    $hasInputOverrides = $false
    if($userInputOverrides -ne $null) {
        $hasInputOverrides = $true
    }

    if($respectOrdering) {
        $configurations = $configurationParameters.PSObject.Properties | Sort-Object { $_.Value.Order }
    }

    foreach ($configurationValue in $configurations) {
        if ($configurationValue.Value.Type -eq "UserInput") {
            if($hasInputOverrides) {
                $userInputOverride = $userInputOverrides.PsObject.Properties | Where-Object { $_.Name -eq $configurationValue.Name }
                if($null -ne $userInputOverride) {
                    $configurationValue.Value.Value = $userInputOverride.Value
                } else {
                    Request-ConfigurationValue $configurationValue.Name $configurationValue.Value
                }
            } else {
                Request-ConfigurationValue $configurationValue.Name $configurationValue.Value
            }
        }
    }

    return $configurationParameters
}