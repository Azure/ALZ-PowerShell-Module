function New-ALZDirectoryEnvironment {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination,
        [string] $alzCicdDestination
    )
    # Create destination file structure
    $gitHubPipeline = Join-Path $alzEnvironmentDestination ".github" "workflows"
    $azureDevOpsPipeline = Join-Path $alzEnvironmentDestination ".azuredevops" "pipelines"
    $config = Join-Path $alzEnvironmentDestination "config"
    $configModules = Join-Path $alzEnvironmentDestination "config" "custom-modules"
    $upstream = Join-Path $alzEnvironmentDestination "upstream-releases"

    New-Item -ItemType Directory -Path $alzEnvironmentDestination -Force | Out-String | Write-Verbose
    $cicd = if ($alzCicdDestination -eq "github") { $gitHubPipeline } else { $azureDevOpsPipeline }
    New-Item -ItemType Directory -Path $cicd -Force | Out-String | Write-Verbose
    New-Item -ItemType Directory -Path $config -Force | Out-String | Write-Verbose
    New-Item -ItemType Directory -Path $upstream -Force | Out-String | Write-Verbose
    New-Item -ItemType Directory -Path $configModules -Force | Out-String | Write-Verbose
}