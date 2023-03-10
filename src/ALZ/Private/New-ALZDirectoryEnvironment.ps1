function New-ALZDirectoryEnvironment {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination
    )
    # Create destination file structure
    $bicepSource = Join-Path $alzEnvironmentDestination "alz-bicep-internal"
    $gitHubPipeline = Join-Path $alzEnvironmentDestination ".github" "workflows"
    $customization = Join-Path $alzEnvironmentDestination "customization"
    $orchestration = Join-Path $alzEnvironmentDestination "orchestration"

    New-Item -ItemType Directory -Path $alzEnvironmentDestination -Force | Out-Null
    New-Item -ItemType Directory -Path $bicepSource -Force | Out-Null
    New-Item -ItemType Directory -Path $gitHubPipeline -Force | Out-Null
    New-Item -ItemType Directory -Path $customization -Force | Out-Null
    New-Item -ItemType Directory -Path $orchestration -Force | Out-Null

}