function Build-ALZDeploymentEnvFile {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $configuration,

        [Parameter(Mandatory = $false)]
        [string] $destination = "."
    )

    $envFile = Join-Path $destination ".env"

    New-Item -Path $envFile -ItemType file -Force | Out-Null

    Add-Content -Path $envFile -Value "IdentitySubscriptionId=`"$($configuration.IdentitySubscriptionId.value)`""
    Add-Content -Path $envFile -Value "ManagementSubscriptionId=`"$($configuration.ManagementSubscriptionId.value)`""
    Add-Content -Path $envFile -Value "ConnectivitySubscriptionId=`"$($configuration.ConnectivitySubscriptionId.value)`""
}