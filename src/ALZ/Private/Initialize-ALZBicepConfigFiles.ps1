function Initialize-ALZBicepConfigFiles {
    param (
        [Parameter(Mandatory = $true)]
        [string] $alzEnvironmentDestination,
        [Parameter(Mandatory = $true)]
        [string] $alzBicepVersion,
        [Parameter(Mandatory = $false)]
        [object] $configuration
    )
    return $true
}