function Invoke-Upgrade {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $targetDirectory,

        [Parameter(Mandatory = $false)]
        [string] $cacheFileName,

        [Parameter(Mandatory = $false)]
        [string] $release,

        [Parameter(Mandatory = $false)]
        [switch] $autoApprove
    )

    if ($PSCmdlet.ShouldProcess("Upgrade Release", "Operation")) {

        $directories = Get-ChildItem -Path $targetDirectory -Filter "v*" -Directory
        $previousCachedValuesPath = $null
        $previousVersion = $null
        $foundPreviousRelease = $false

        foreach ($directory in $directories | Sort-Object -Descending -Property Name) {
            $releasePath = Join-Path -Path $targetDirectory -ChildPath $directory.Name
            $releaseCachedValuesPath = Join-Path -Path $releasePath -ChildPath $cacheFileName

            if(Test-Path $releaseCachedValuesPath) {
                $previousCachedValuesPath = $releaseCachedValuesPath
            }

            if($null -ne $previousCachedValuesPath) {
                if($directory.Name -eq $release) {
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
            $upgrade = ""
            if($autoApprove) {
                $upgrade = "upgrade"
            } else {
                $upgrade = Read-Host "If you would like to upgrade, enter 'upgrade' or just hit 'enter' to continue with a new environment. (upgrade/exit)"
            }

            if($upgrade.ToLower() -eq "upgrade") {
                $currentPath = Join-Path -Path $targetDirectory -ChildPath $release
                $currentCachedValuesPath = Join-Path -Path $currentPath -ChildPath $cacheFileName

                # Copy the previous cached values to the current release
                if($null -ne $previousCachedValuesPath) {
                    Write-InformationColored "AUTOMATIC UPGRADE: Copying $previousCachedValuesPath to $currentCachedValuesPath" -ForegroundColor Green -InformationAction Continue
                    Copy-Item -Path $previousCachedValuesPath -Destination $currentCachedValuesPath -Force | Out-String | Write-Verbose
                }

                Write-InformationColored "AUTOMATIC UPGRADE: Copying $previousStateFilePath to $currentStateFilePath" -ForegroundColor Green -InformationAction Continue
                Copy-Item -Path $previousStateFilePath -Destination $currentStateFilePath -Force | Out-String | Write-Verbose

                Write-InformationColored "AUTOMATIC UPGRADE: Upgrade complete. If any files in the starter have been updated, you will need to remove branch protection in order for the Terraform apply to succeed..." -ForegroundColor Yellow -InformationAction Continue
                return $true
            }
        }

        return $false
    }
}
