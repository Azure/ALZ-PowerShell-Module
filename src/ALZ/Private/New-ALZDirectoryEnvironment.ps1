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
    $gitHubPipeline = Join-Path $alzEnvironmentDestination ".github" "workflows"
    $config = Join-Path $alzEnvironmentDestination "config"
    $configModules = Join-Path $alzEnvironmentDestination "config" "modules"
    $upstream = Join-Path $alzEnvironmentDestination "upstream-releases"

    New-Item -ItemType Directory -Path $alzEnvironmentDestination -Force | Out-Null
    New-Item -ItemType Directory -Path $gitHubPipeline -Force | Out-Null
    New-Item -ItemType Directory -Path $config -Force | Out-Null
    New-Item -ItemType Directory -Path $upstream -Force | Out-Null
    New-Item -ItemType Directory -Path $configModules -Force | Out-Null

}