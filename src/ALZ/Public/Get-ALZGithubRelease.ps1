####################################
# Get-ALZGithubRelease.ps1 #
####################################
# Version: 0.1.0
# Based on Invoke-GitHubReleaseFetcher by Jack Tracey:
# Source: https://github.com/jtracey93/PublicScripts/blob/master/GitHub/PowerShell/Invoke-GitHubReleaseFetcher.ps1

<#
.SYNOPSIS
Checks for the releases of a GitHub repository and downloads the latest release or all releases and pulls it into a specified directory, one for each version.
.DESCRIPTION
Checks for the releases of a GitHub repository and downloads the latest release or all releases and pulls it into a specified directory, one for each version.

.EXAMPLE

.NOTES
# Release notes 16/03/2023 - V0.1.0:
- Initial release.
#>


function Get-ALZGithubRelease {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Please the provide the full URL of the GitHub repository you wish to check for the latest release.")]
        [string]
        $githubRepoUrl,

        [Parameter(Mandatory = $false, Position = 2, HelpMessage = "The releases to download. Specify 'all' to download all releases or 'latest' to download the latest release. Defaults to the latest release.")]
        [array]
        $releases = @("latest"),

        [Parameter(Mandatory = $false, Position = 3, HelpMessage = "The directory to download the releases to. Defaults to the current directory.")]
        [string]
        $directoryForReleases = "$PWD/releases",

        [Parameter(Mandatory = $false, Position = 4, HelpMessage = "An array of strings contianing the paths to the directories or files that you wish to keep when downloading and extracting from the releases.")]
        [array]
        $directoryAndFilesToKeep = $null,

        [Parameter(Mandatory = $false, Position = 4, HelpMessage = "Whether to just query the API and return the release versions.")]
        [switch]
        $queryOnly
    )

    # Split Repo URL into parts
    $repoOrgPlusRepo = $githubRepoUrl.Split("/")[-2..-1] -join "/"

    Write-Verbose "=====> Checking for releases on GitHub Repo: $repoOrgPlusRepo"

    # Get releases on repo
    $repoReleasesUrl = "https://api.github.com/repos/$repoOrgPlusRepo/releases"
    $allRepoReleases = Invoke-RestMethod $repoReleasesUrl -RetryIntervalSec 3 -MaximumRetryCount 100

    Write-Verbose "=====> All available releases on GitHub Repo: $repoOrgPlusRepo"
    $allRepoReleases | Select-Object name, tag_name, published_at, prerelease, draft, html_url | Format-Table -AutoSize | Out-String | Write-Verbose

    # Get latest release on repo
    $latestRepoRelease = $allRepoReleases | Where-Object { $_.prerelease -eq $false } | Where-Object { $_.draft -eq $false } | Sort-Object -Descending published_at | Select-Object -First 1
    # replace latest with the tag of the latest release
    if ($releases -contains "latest") {
        $releases += $latestRepoRelease.tag_name
        $releases = $releases | Where-Object { $_ -ne "latest" }
    }

    Write-Verbose "=====> Latest available release on GitHub Repo: $repoOrgPlusRepo"
    $latestRepoRelease | Select-Object name, tag_name, published_at, prerelease, draft, html_url | Format-Table -AutoSize | Out-String | Write-Verbose

    # Check if directory exists
    Write-Verbose "=====> Checking if directory for releases exists: $directoryForReleases"

    if (!(Test-Path $directoryForReleases)) {
        Write-Verbose "Directory does not exist for releases, will now create: $directoryForReleases"
        New-Item -ItemType Directory -Path $directoryForReleases | Out-String | Write-Verbose
    }

    # if all is specified add all the releases to the array and remove all
    if ($releases -contains "all") {
        $releases = $allRepoReleases | Select-Object -ExpandProperty tag_name
        $releases = $releases | Where-Object { $_ -ne "all" }
    }

    # Remove all the releases that were not found
    foreach ($release in $releases) {
        if (($allRepoReleases | Where-Object { $_.tag_name -eq $release } | Measure-Object).Count -eq 0) {
            Write-Warning "Release $release was not found on GitHub Repo: $repoOrgPlusRepo"
            $releases = $releases | Where-Object { $_ -ne $release }
        }
    }

    $selectedReleases = $allRepoReleases | Where-Object { $releases -contains $_.tag_name }

    if($queryOnly) {
        return $selectedReleases
    }

    foreach ($release in $selectedReleases) {
        # Check the firectory for this release
        $releaseDirectory = "$directoryForReleases/$($release.tag_name)"

        Write-Verbose "===> Checking if directory for release version exists: $releaseDirectory"

        if (!(Test-Path $releaseDirectory)) {
            Write-Verbose "Directory does not exist for release $($release.tag_name), will now create: $releaseDirectory"
            New-Item -ItemType Directory -Path $releaseDirectory | Out-String | Write-Verbose
        }

        Write-Verbose "===> Checking if any content exists inside of $releaseDirectory"

        $contentInReleaseDirectory = Get-ChildItem -Path $releaseDirectory -Recurse -ErrorAction SilentlyContinue

        if ($null -eq $contentInReleaseDirectory) {
            Write-Verbose "===> Pulling and extracting release $($release.tag_name) into $releaseDirectory"
            New-Item -ItemType Directory -Path "$releaseDirectory/tmp" | Out-String | Write-Verbose
            Invoke-WebRequest -Uri "https://github.com/$repoOrgPlusRepo/archive/refs/tags/$($release.tag_name).zip" -OutFile "$releaseDirectory/tmp/$($release.tag_name).zip" -RetryIntervalSec 3 -MaximumRetryCount 100 | Out-String | Write-Verbose
            Expand-Archive -Path "$releaseDirectory/tmp/$($release.tag_name).zip" -DestinationPath "$releaseDirectory/tmp/extracted" | Out-String | Write-Verbose
            $extractedSubFolder = Get-ChildItem -Path "$releaseDirectory/tmp/extracted" -Directory

            if ($null -ne $directoryAndFilesToKeep) {
                foreach ($path in $directoryAndFilesToKeep) {
                    Write-Verbose "===> Moving $path into $releaseDirectory."
                    Move-Item -Path "$($extractedSubFolder.FullName)/$($path)" -Destination "$releaseDirectory" -ErrorAction SilentlyContinue | Out-String | Write-Verbose
                }
            }

            if ($null -eq $directoryAndFilesToKeep) {
                Write-Verbose "===> Moving all extracted contents into $releaseDirectory."
                Move-Item -Path "$($extractedSubFolder.FullName)/*" -Destination "$releaseDirectory" -ErrorAction SilentlyContinue | Out-String | Write-Verbose
            }

            Remove-Item -Path "$releaseDirectory/tmp" -Force -Recurse

        } else {
            Write-Verbose "===> Content already exists in $releaseDirectory. Skipping"
        }
    }
    return $selectedReleases
}