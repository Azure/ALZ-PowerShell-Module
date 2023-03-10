function Initialize-ALZBicepConfigFile {
    param (
        [Parameter(Mandatory = $true)]
        [string] $alzEnvironmentDestination,
        [Parameter(Mandatory = $true)]
        [string] $alzBicepVersion,
        [Parameter(Mandatory = $false)]
        [object] $configuration
    )
    Write-InformationColored "Initializing ALZ-Bicep configuration files..." -ForegroundColor Green  -InformationAction Continue
    Write-InformationColored "alzEnvironmentDestination: $alzEnvironmentDestination" -ForegroundColor Green  -InformationAction Continue
    Write-InformationColored "alzBicepVersion: $alzBicepVersion" -ForegroundColor Green  -InformationAction Continue
    Write-InformationColored "configuration: $configuration" -ForegroundColor Green  -InformationAction Continue
    return $true
}