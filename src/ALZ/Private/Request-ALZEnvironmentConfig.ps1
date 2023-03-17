
function Request-ALZEnvironmentConfig {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("bicep", "terraform")]
        [string] $alzIacProvider,

        [Parameter(Mandatory = $true)]
        [string] $alzEnvironmentDestination,

        [Parameter(Mandatory = $true)]
        [string] $alzBicepVersion
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
    if ($alzIacProvider -eq "terraform") {
        throw "Terraform is not yet supported."
    }

    $configuration = Get-Configuration -alzIacProvider $alzIacProvider -alzEnvironmentDestination $alzEnvironmentDestination -alzBicepVersion $alzBicepVersion
    Write-Verbose "Configuration object initialized."
    Write-Verbose "Configuration object: $(ConvertTo-Json $configuration -Depth 10)"

    foreach ($configurationValue in $configuration.PsObject.Properties) {
        if ($configurationValue.Value.Type -eq "UserInput") {
            Request-ConfigurationValue $configurationValue.Name $configurationValue.Value
        }
    }

    return $configuration
}