function Get-ALZConfig {
    <#

    #>
    param(
        [Parameter(Mandatory = $false)]
        [string] $configFilePath = ""
    )

    # Import the config and transform it to a PowerShell object
    $extension = (Get-Item -Path $configFilePath).Extension.ToLower()
    if($extension -eq ".yml" -or $extension -eq ".yaml") {
        if (!(Get-Module -ListAvailable -Name powershell-Yaml)) {
            Write-Host "Installing YAML module"
            Install-Module powershell-Yaml -Force
        }
        $config = [PSCustomObject](Get-Content -Path $configFilePath | ConvertFrom-Yaml)
    } elseif($extension -eq ".json") {
        $config = Get-Content -Path $configFilePath | ConvertFrom-Json
    } else {
        throw "The config file must be a json or yaml/yml file"
    }

    return $config
}