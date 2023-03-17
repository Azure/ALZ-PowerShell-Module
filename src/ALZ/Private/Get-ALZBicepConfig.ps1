function Get-ALZBicepConfig {
    <#

    #>
    param(
        [Parameter(Mandatory = $false)]
        [string] $alzBicepVersion = "v0.13.0"
    )
    # import the config from the json file inside assets and tranform it to a powershell object
    $bicepConfig = Get-Content -Path (Join-Path $(Get-ScriptRoot) "../Assets/alz-bicep-config" "$alzBicepVersion.config.json" ) | ConvertFrom-Json
    return $bicepConfig
}