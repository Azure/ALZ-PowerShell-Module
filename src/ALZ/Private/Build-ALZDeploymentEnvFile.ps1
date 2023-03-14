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

    New-Item -Path $envFile -ItemType file -Force | Out-Null

    foreach ($configurationValue in $configuration.PsObject.Properties) {
        if ($configurationValue.Value.Type -eq "Environment") {
            Add-Content -Path $envFile -Value "$($($configurationValue.Name))=`"$($configurationValue.Value.Value)`""
        }
    }
}