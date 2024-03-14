function Copy-ALZParametersFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination,

        [Parameter(Mandatory = $true)]
        [string]$upstreamReleaseDirectory,

        [Parameter(Mandatory = $true)]
        [array]$configFiles
    )
    foreach ($configFile in $configFiles) {
        $sourcePath = Join-Path $upstreamReleaseDirectory $configFile.source
        $destinationPath = Join-Path $alzEnvironmentDestination $configFile.destination
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