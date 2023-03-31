function Build-ALZDeploymentEnvFile {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $configuration,

        [Parameter(Mandatory = $false)]
        [string] $destination = "."
    )
    <#
    .SYNOPSIS
        This function uses configuration to build a .env file for use in the deployment pipeline.
    .EXAMPLE
    Build-ALZDeploymentEnvFile -configuration configuration
    .EXAMPLE
    Build-ALZDeploymentEnvFile -configuration configuration -destination "."
    .OUTPUTS
    N/A
    #>

    $envFile = Join-Path $destination ".env"

    New-Item -Path $envFile -ItemType file -Force | Out-String | Write-Verbose

    foreach ($configurationValue in $configuration.PsObject.Properties) {
        foreach ($target in $configurationValue.Value.Targets) {
            if ($target.Destination -eq "Environment") {

                $formattedValue = $configurationValue.Value.Value
                if ($configurationValue.Value.Type -eq "Computed") {
                    $formattedValue = Format-TokenizedConfigurationString -tokenizedString $configurationValue.Value.Value -configuration $configuration
                }

                Add-Content -Path $envFile -Value "$($($target.Name))=`"$formattedValue`"" | Out-String | Write-Verbose
            }
        }
    }
}