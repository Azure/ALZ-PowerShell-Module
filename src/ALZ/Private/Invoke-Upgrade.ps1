function Invoke-Upgrade {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $alzEnvironmentDestination,

        [Parameter(Mandatory = $false)]
        [string] $bootstrapCacheFileName,

        [Parameter(Mandatory = $false)]
        [string] $starterCacheFileNamePattern,

        [Parameter(Mandatory = $false)]
        [string] $stateFilePathAndFileName,

        [Parameter(Mandatory = $false)]
        [string] $currentVersion
    )

    if ($PSCmdlet.ShouldProcess("Upgrade Release", "Operation")) {

        $directories = Get-ChildItem -Path $alzEnvironmentDestination -Filter "v*" -Directory
        $previousBootstrapCachedValuesPath = $null
        $previousStarterCachedValuesPath = $null
        $previousStateFilePath = $null
        $previousVersion = $null
        $foundPreviousRelease = $false

        foreach ($directory in $directories | Sort-Object -Descending -Property Name) {
            $releasePath = Join-Path -Path $alzEnvironmentDestination -ChildPath $directory.Name
            $releaseBootstrapCachedValuesPath = Join-Path -Path $releasePath -ChildPath $bootstrapCacheFileName
            $releaseStateFilePath = Join-Path -Path $releasePath -ChildPath $stateFilePathAndFileName

            if(Test-Path $releaseBootstrapCachedValuesPath) {
                $previousBootstrapCachedValuesPath = $releaseBootstrapCachedValuesPath
            }

            $starterCacheFiles = Get-ChildItem -Path $releasePath -Filter $starterCacheFileNamePattern -File

            if($starterCacheFiles) {
                $previousStarterCachedValuesPath = $starterCacheFiles[0].FullName
            }

            if(Test-Path $releaseStateFilePath) {
                $previousStateFilePath = $releaseStateFilePath
            }

            if($null -ne $previousStateFilePath) {
                if($directory.Name -eq $currentVersion) {
                    # If the current version has already been run, then skip the upgrade process
                    break
                }

                $foundPreviousRelease = $true
                $previousVersion = $directory.Name
                break
            }
        }

        if($foundPreviousRelease) {
            Write-InformationColored "AUTOMATIC UPGRADE: We found version $previousVersion that has been previously run. You can upgrade from this version to the new version $currentVersion" -ForegroundColor Yellow -InformationAction Continue
            $upgrade = Read-Host "If you would like to upgrade, enter 'upgrade' or just hit 'enter' to continue with a new environment. (upgrade/exit)"

            if($upgrade.ToLower() -eq "upgrade") {
                $currentPath = Join-Path -Path $alzEnvironmentDestination -ChildPath $currentVersion
                $currentBootstrapCachedValuesPath = Join-Path -Path $currentPath -ChildPath $bootstrapCacheFileName
                $currentStarterCachedValuesPath = $currentPath
                $currentStateFilePath = Join-Path -Path $currentPath -ChildPath $stateFilePathAndFileName

                # Copy the previous cached values to the current release
                if($null -ne $previousBootstrapCachedValuesPath) {
                    Write-InformationColored "AUTOMATIC UPGRADE: Copying $previousBootstrapCachedValuesPath to $currentBootstrapCachedValuesPath" -ForegroundColor Green -InformationAction Continue
                    Copy-Item -Path $previousBootstrapCachedValuesPath -Destination $currentBootstrapCachedValuesPath -Force | Out-String | Write-Verbose
                }
                if($null -ne $previousStarterCachedValuesPath) {
                    Write-InformationColored "AUTOMATIC UPGRADE: Copying $previousStarterCachedValuesPath to $currentStarterCachedValuesPath" -ForegroundColor Green -InformationAction Continue
                    Copy-Item -Path $previousStarterCachedValuesPath -Destination $currentStarterCachedValuesPath -Force | Out-String | Write-Verbose
                }

                Write-InformationColored "AUTOMATIC UPGRADE: Copying $previousStateFilePath to $currentStateFilePath" -ForegroundColor Green -InformationAction Continue
                Copy-Item -Path $previousStateFilePath -Destination $currentStateFilePath -Force | Out-String | Write-Verbose

                Write-InformationColored "AUTOMATIC UPGRADE: Upgrade complete. If any files in the starter have been updated, you will need to remove branch protection in order for the Terraform apply to succeed..." -ForegroundColor Yellow -InformationAction Continue
                Read-Host "Press any key to continue to acknowlege the requirement to remove branch protection..."
            }
        }
    }
}
