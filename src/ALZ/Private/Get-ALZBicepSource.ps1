function Get-ALZBicepSource {
    param (
        [Parameter(Mandatory = $false)]
        [string] $alzBicepVersion = "v0.13.0"
    )
    $scriptRoot = Get-ScriptRoot
    $alzBicepSource = Join-Path $scriptRoot ".." $alzBicepVersion

    Write-Verbose "ALZ Bicep Source Directory: $scriptRoot $alzBicepSource"
    return (Get-ChildItem -Path $alzBicepSource -Directory)[0].FullName
}