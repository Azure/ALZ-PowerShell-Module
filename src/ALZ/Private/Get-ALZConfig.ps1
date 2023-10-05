function Get-ALZConfig {
    <#

    #>
    param(
        [Parameter(Mandatory = $false)]
        [string] $alzVersion = "v0.16.4",
        [Parameter(Mandatory = $false)]
        [ValidateSet("bicep", "terraform")]
        [Alias("Iac")]
        [string] $alzIacProvider = "bicep",
        [Parameter(Mandatory = $false)]
        [string] $configFilePath = ""
    )

    # Import the config from the json file inside assets and transform it to a PowerShell object
    if ($configFilePath -ne "") {
        $config = Get-Content -Path $configFilePath | ConvertFrom-Json
        return $config
    }

    else {
        $config = Get-Content -Path (Join-Path $(Get-ScriptRoot) "../Assets/alz-$alzIacProvider-config" "$alzVersion.config.json" ) | ConvertFrom-Json
        return $config
    }
}