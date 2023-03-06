function Get-ALZBicepSource {
    param (
        [Parameter(Mandatory = $false)]
        [string] $alzBicepVersion = "v0.13.0"
    )
    $alzBicepSource = Join-Path $(Get-ScriptRoot) $alzBicepVersion
    return (Get-ChildItem -Path $alzBicepSource -Directory)[0].FullName
}