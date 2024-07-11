function Invoke-Upgrade {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $moduleType,

        [Parameter(Mandatory = $false)]
        [string] $targetDirectory,

        [Parameter(Mandatory = $false)]
        [string] $targetFolder = "",

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

        Write-Verbose "UPGRADE: Checking for existing directories in $targetDirectory"

        foreach ($directory in $directories | Sort-Object -Descending -Property Name) {
            $releasePath = Join-Path $targetDirectory $directory.Name
            $releaseCachedValuesPath = Join-Path $releasePath $targetFolder $cacheFileName

            Write-Verbose "UPGRADE: Checking for existing file in $releasePath, specifically $releaseCachedValuesPath"

            if(Test-Path $releaseCachedValuesPath) {
                $previousCachedValuesPath = $releaseCachedValuesPath
            }

            if($null -ne $previousCachedValuesPath) {
                if($directory.Name -eq $release) {
                    Write-Verbose "Latest version $release has already been run. Skipping upgrade..."
                    # If the current version has already been run, then skip the upgrade process
                    break
                }

                $foundPreviousRelease = $true
                $previousVersion = $directory.Name
                break
            }
        }

        if($foundPreviousRelease) {
            $upgrade = $true
            if($autoApprove) {
                $upgrade = $true
            } else {
                Write-InformationColored "AUTOMATIC UPGRADE: We found version $previousVersion of the $moduleType module that has been previously run. You can migrate your settings and state from this version to the new version $currentVersion" -NewLineBefore -ForegroundColor Yellow -InformationAction Continue
                $choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Yes", "&No")
                $message = "Please confirm you wish to migrate your previous settings and state to the new version."
                $title = "Confirm migrate settings and state"
                $resultIndex = $host.ui.PromptForChoice($title, $message, $choices, 0)

                if($resultIndex -eq 1) {
                    Write-InformationColored "You have chosen not to migrate your settings and state. Please note that your state file is still in the folder for the previous version if this was a mistake." -ForegroundColor Yellow -NewLineBefore -InformationAction Continue
                    $upgrade = $false
                }
            }

            if($upgrade) {
                $currentPath = Join-Path $targetDirectory $release
                $currentCachedValuesPath = Join-Path $currentPath $targetFolder $cacheFileName

                # Copy the previous cached values to the current release
                if($null -ne $previousCachedValuesPath) {
                    Write-InformationColored "AUTOMATIC UPGRADE: Copying $previousCachedValuesPath to $currentCachedValuesPath" -ForegroundColor Green -InformationAction Continue
                    Copy-Item -Path $previousCachedValuesPath -Destination $currentCachedValuesPath -Force | Out-String | Write-Verbose
                }

                return $true
            }
        }

        return $false
    }
}
