function Create-ALZDeploymentEnvFile {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $configuration
    )
    $envFile = Join-Path $configuration.alzEnvironmentDestination ".env"
    $envFileContent = @"
    IdentitySubscriptionId=$($configuration.IdentitySubscriptionId.value)
    ManagementSubscriptionId=$($configuration.ManagementSubscriptionId.value)
    ConnectivitySubscriptionId=$($configuration.ConnectivitySubscriptionId.value)
    "
    $envFileContent | Out-File $envFile
}