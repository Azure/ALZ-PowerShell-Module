function Copy-ParametersFileCollection {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $starterPath,

        [Parameter(Mandatory = $true)]
        [array]$configFiles
    )
    foreach ($configFile in $configFiles) {
        $sourcePath = Join-Path $starterPath $configFile.templateParametersSourceFilePath
        $destinationPath = Join-Path $starterPath $configFile.templateParametersFilePath
        if (Test-Path $sourcePath) {
            if ($PSCmdlet.ShouldProcess($sourcePath, "Copy")) {
                # create destination folder if it does not exists
                $destinationFolder = Split-Path -Path $destinationPath -Parent
                if (-not (Test-Path $destinationFolder)) {
                    New-Item -ItemType Directory -Path $destinationFolder -Force | Out-String | Write-Verbose
                }
                Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force | Out-String | Write-Verbose
            }
        } else {
            Write-Warning "The file $sourcePath does not exist."
        }
    }
}
