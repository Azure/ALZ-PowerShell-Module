function New-ALZDirectoryEnvironment {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination,

        [Parameter(Mandatory = $true)]
        [object] $configuration
    )
    # Create destination file structure
    $alzEnvironmentDestination = Resolve-Path $alzEnvironmentDestination

    New-Item -ItemType Directory -Path $alzEnvironmentDestination -Force | Out-Null

    Write-Information $configuration


}