function Get-ExistingLocalRelease {
    param(
        [Parameter(Mandatory = $false)]
        [string] $targetDirectory,

        [Parameter(Mandatory = $false)]
        [string] $targetFolder
    )

    $releaseTag = ""
    $path = ""
    $checkPath = Join-Path $targetDirectory $targetFolder
    $checkFolders = Get-ChildItem -Path $checkPath -Directory
    if ($null -ne $checkFolders) {
        $checkFolders = $checkFolders | Sort-Object { $_.Name } -Descending
        $mostRecentCheckFolder = $checkFolders[0]

        $releaseTag = $mostRecentCheckFolder.Name
        $path = $mostRecentCheckFolder.FullName
    } else {
        Write-InformationColored "You have passed the skipInternetChecks parameter, but there is no existing version in the $targetFolder module, so we can't continue."
        throw
    }

    return @{
        releaseTag = $releaseTag
        path       = $path
    }
}
