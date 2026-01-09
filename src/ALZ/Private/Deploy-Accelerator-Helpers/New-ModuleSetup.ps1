
function New-ModuleSetup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$targetDirectory,
        [Parameter(Mandatory = $false)]
        [string]$targetFolder,
        [Parameter(Mandatory = $false)]
        [string]$sourceFolder,
        [Parameter(Mandatory = $false)]
        [string]$url,
        [Parameter(Mandatory = $false)]
        [string]$release,
        [Parameter(Mandatory = $false)]
        [string]$releaseArtifactName = "",
        [Parameter(Mandatory = $false)]
        [string]$moduleOverrideFolderPath,
        [Parameter(Mandatory = $false)]
        [bool]$skipInternetChecks,
        [Parameter(Mandatory = $false)]
        [switch]$replaceFiles,
        [Parameter(Mandatory = $false)]
        [switch]$upgrade,
        [Parameter(Mandatory = $false)]
        [switch]$autoApprove
    )

    if ($PSCmdlet.ShouldProcess("Check and get module", "modify")) {

        $currentVersion = Get-ModuleVersionData -targetDirectory $targetDirectory -moduleType $targetFolder
        $versionAndPath = @{
            path       = Join-Path $targetDirectory $targetFolder $currentVersion
            releaseTag = $currentVersion
        }
        Write-Verbose "Current $targetFolder module version: $currentVersion"
        Write-Verbose "Current $targetFolder module path: $($versionAndPath.path)"

        if($skipInternetChecks) {
            return $versionAndPath
        }

        $latestReleaseTag = $null
        try {
            $latestResult = Get-GithubReleaseTag -githubRepoUrl $url -release "latest"
            $latestReleaseTag = $latestResult.ReleaseTag
            Write-Verbose "Latest available $targetFolder version: $latestReleaseTag"
        } catch {
            Write-Verbose "Could not check for latest version: $($_.Exception.Message)"
        }

        $isAutoVersion = $release -eq "latest"
        $firstRun = $null -eq $currentVersion
        $shouldDownload = $false

        if($isAutoVersion -and $upgrade.IsPresent -and $null -eq $latestReleaseTag) {
            throw "Cannot perform upgrade to latest version as unable to determine latest release from GitHub."
        }

        if($isAutoVersion -and $upgrade.IsPresent -and $currentVersion -ne $latestReleaseTag) {
            Write-Verbose "Auto version upgrade requested and newer version available."
            $shouldDownload = $true
        }

        if(!$isAutoVersion -and $upgrade.IsPresent -and $release -ne $currentVersion -and $currentVersion -ne $latestReleaseTag) {
            Write-Verbose "Specific version upgrade requested and newer version available."
            $shouldDownload = $true
        }

        if($firstRun) {
            Write-Verbose "First run detected, will download specified version."
            $shouldDownload = $true
        }

        if(!$shouldDownload -or $isFirstRun) {
            $newVersionAvailable = $false
            $currentCalculatedVersion = $currentVersion
            if($isAutoVersion -and $null -ne $latestReleaseTag -and $latestReleaseTag -ne $currentVersion) {
                $newVersionAvailable = $true
            }

            if(!$isAutoVersion -and $null -ne $latestReleaseTag -and $latestReleaseTag -ne $currentVersion) {
                $newVersionAvailable = $true
            }

            if($isFirstRun -and !$isAutoVersion -and $release -ne $latestReleaseTag) {
                $currentCalculatedVersion = $release
                $newVersionAvailable = $true
            }

            if($newVersionAvailable) {
                Write-InformationColored "INFO: A newer $targetFolder module version is available ($latestReleaseTag). You are currently using $currentCalculatedVersion." -ForegroundColor Cyan -InformationAction Continue
                Write-InformationColored "      To upgrade, run with the -upgrade flag." -ForegroundColor Cyan -InformationAction Continue
            } else {
                if(!$firstRun) {
                    if($upgrade.IsPresent) {
                        Write-InformationColored "No upgrade required for $targetFolder module; already at latest version ($currentCalculatedVersion)." -ForegroundColor Yellow -InformationAction Continue
                    }
                    Write-InformationColored "Using existing $targetFolder module version ($currentCalculatedVersion)." -ForegroundColor Green -InformationAction Continue
                } else {
                    Write-InformationColored "Using specified $targetFolder module version ($currentCalculatedVersion) for the first run." -ForegroundColor Green -InformationAction Continue
                }
            }
        }

        if ($shouldDownload) {

            $previousVersionPath = $versionAndPath.path
            $desiredRelease = $isAutoVersion ? $latestReleaseTag : $release
            Write-InformationColored "Upgrading $targetFolder module from $currentVersion to $desiredRelease" -ForegroundColor Yellow -InformationAction Continue

            if (-not $autoApprove.IsPresent) {
                $confirm = Read-Host "Do you want to proceed with the upgrade? (y/n)"
                if ($confirm -ne "y" -and $confirm -ne "Y") {
                    Write-InformationColored "Upgrade declined. Continuing with existing version $currentVersion." -ForegroundColor Yellow -InformationAction Continue
                    return $versionAndPath
                }
            }

            $versionAndPath = New-FolderStructure `
                -targetDirectory $targetDirectory `
                -url $url `
                -release $desiredRelease `
                -releaseArtifactName $releaseArtifactName `
                -targetFolder $targetFolder `
                -sourceFolder $sourceFolder `
                -overrideSourceDirectoryPath $moduleOverrideFolderPath `
                -replaceFiles:$replaceFiles.IsPresent

            Write-Verbose "New version: $($versionAndPath.releaseTag) at path: $($versionAndPath.path)"

            if (!$isFirstRun) {
                Write-Verbose "Checking for state files at: $previousStatePath"
                $previousStateFiles = Get-ChildItem $previousVersionPath -Filter "terraform.tfstate" -Recurse | Select-Object -First 1 | ForEach-Object { $_.FullName }

                if ($previousStateFiles.Count -gt 0) {
                    foreach ($stateFile in $previousStateFiles) {
                        $previousStateFilePath = $stateFile
                        $newStateFilePath = $previousStateFilePath.Replace($previousVersionPath, $versionAndPath.path)
                        Write-InformationColored "Copying state file from $previousStateFilePath to $newStateFilePath" -ForegroundColor Green -InformationAction Continue
                        Copy-Item -Path $previousStateFilePath -Destination $newStateFilePath -Force | Out-String | Write-Verbose
                    }
                } else {
                    Write-Verbose "No state files found at $previousVersionPath - skipping migration"
                }

                Write-InformationColored "Module $targetFolder upgraded from version $currentVersion to $($versionAndPath.releaseTag)." -ForegroundColor Green -InformationAction Continue
                Write-InformationColored "  If any repository files have been updated in the new version, you'll need to turn off branch protection for the run to succeed..." -ForegroundColor Yellow -InformationAction Continue
            }

            # Update version data
            Set-ModuleVersionData -targetDirectory $targetDirectory -moduleType $targetFolder -version $versionAndPath.releaseTag | Out-Null
        }

        return $versionAndPath
    }
}
