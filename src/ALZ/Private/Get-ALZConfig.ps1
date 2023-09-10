function Get-ALZConfig {
    <#

    #>
    param(
        [Parameter(Mandatory = $false)]
        [string] $alzVersion = "v0.16.3",
        [Parameter(Mandatory = $false)]
        [ValidateSet("bicep", "terraform")]
        [Alias("Iac")]
        [string] $alzIacProvider = "bicep"
    )
    # import the config from the json file inside assets and tranform it to a powershell object
    $config = Get-Content -Path (Join-Path $(Get-ScriptRoot) "../Assets/alz-$alzIacPRovider-config" "$alzVersion.config.json" ) | ConvertFrom-Json
    return $config
}