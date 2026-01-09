function Set-ModuleVersionData {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $targetDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateSet("bootstrap", "starter")]
        [string] $moduleType,

        [Parameter(Mandatory = $true)]
        [string] $version
    )

    if ($PSCmdlet.ShouldProcess($targetDirectory, "Set module version data")) {
        $dataFilePath = Join-Path $targetDirectory ".alz-version-data.json"

        # Load existing data or create new
        if (Test-Path $dataFilePath) {
            $data = Get-Content $dataFilePath | ConvertFrom-Json
        } else {
            $data = [PSCustomObject]@{
                bootstrapVersion = $null
                starterVersion   = $null
                lastUpdated      = $null
            }
        }

        # Update the data
        $versionKey = "$($moduleType)Version"
        $data.$versionKey = $version
        $data.lastUpdated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")

        # Save data
        $data | ConvertTo-Json -Depth 10 | Set-Content $dataFilePath

        return $data
    }
}
