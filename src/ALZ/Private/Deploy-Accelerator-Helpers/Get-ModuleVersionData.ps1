function Get-ModuleVersionData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $targetDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateSet("bootstrap", "starter")]
        [string] $moduleType
    )

    $dataFilePath = Join-Path $targetDirectory ".alz-version-data.json"

    if (Test-Path $dataFilePath) {
        $data = Get-Content $dataFilePath | ConvertFrom-Json
        $versionKey = "$($moduleType)Version"
        return $data.$versionKey
    }

    return $null
}
