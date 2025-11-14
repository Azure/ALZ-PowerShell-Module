####################################
# Get-GithubRelease.ps1 #
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


function Get-GithubRelease {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Please the provide the full URL of the GitHub repository you wish to check for the latest release.")]
        [string]
        $githubRepoUrl,

        [Parameter(Mandatory = $false, Position = 2, HelpMessage = "The releases to download. Specify 'latest' to download the latest release. Defaults to the latest release.")]
        [array]
        $release = "latest",

        [Parameter(Mandatory = $true, Position = 3, HelpMessage = "The directory to download the releases to.")]
        [string]
        $targetDirectory,

        [Parameter(Mandatory = $false, Position = 4, HelpMessage = "Whether to just query the API and return the release versions.")]
        [switch]
        $queryOnly,

        [Parameter(Mandatory = $false, HelpMessage = "The source directory location of the modules. Defaults to root")]
        $moduleSourceFolder = ".",

        [Parameter(Mandatory = $true, HelpMessage = "The target directory location of the modules.")]
        $moduleTargetFolder,

        [Parameter(Mandatory = $false, HelpMessage = "The name of the release artifact in the target release. Defaults to standard release zip.")]
        $releaseArtifactName = ""
    )

    $parentDirectory = $targetDirectory
    $targetPath = Join-Path $targetDirectory $moduleTargetFolder

    # Split Repo URL into parts
    $repoOrgPlusRepo = $githubRepoUrl.Split("/")[-2..-1] -join "/"

    Write-Verbose "=====> Checking for release on GitHub Repo: $repoOrgPlusRepo"

    # Get releases on repo
    $repoReleaseUrl = "https://api.github.com/repos/$repoOrgPlusRepo/releases/$release"
    if($release -ne "latest") {
        $repoReleaseUrl = "https://api.github.com/repos/$repoOrgPlusRepo/releases/tags/$release"
    }

    $releaseData = Invoke-RestMethod $repoReleaseUrl -SkipHttpErrorCheck -StatusCodeVariable "statusCode"

    Write-Verbose "Status code: $statusCode"

    if($statusCode -eq 404) {
        Write-Error "The release $release does not exist in the GitHub repository $githubRepoUrl - $repoReleaseUrl"
        throw "The release $release does not exist in the GitHub repository $githubRepoUrl - $repoReleaseUrl"
    }

    # Handle transient errors like throttling
    if($statusCode -ge 400 -and $statusCode -le 599) {
        Write-InformationColored "Retrying as got the Status Code $statusCode, which may be a transient error." -ForegroundColor Yellow -InformationAction Continue
        $releaseData = Invoke-RestMethod $repoReleaseUrl -RetryIntervalSec 3 -MaximumRetryCount 100
    }

    if($statusCode -ne 200) {
        throw "Unable to query repository version, please check your internet connection and try again..."
    }

    $releaseTag = $releaseData.tag_name

    if($queryOnly) {
        return $releaseTag
    }

    # Check if directory exists
    Write-Verbose "=====> Checking if directory for releases exists: $targetPath"

    if (!(Test-Path $targetPath)) {
        Write-Verbose "Directory does not exist for releases, will now create: $targetPath"
        New-Item -ItemType Directory -Path $targetPath | Out-String | Write-Verbose
    }

    # Check the directory for this release
    $targetVersionPath = Join-Path $targetPath $releaseTag

    Write-Verbose "===> Checking if directory for release version exists: $targetVersionPath"

    if (!(Test-Path $targetVersionPath)) {
        Write-Verbose "Directory does not exist for release $releaseTag, will now create: $targetVersionPath"
        New-Item -ItemType Directory -Path $targetVersionPath | Out-String | Write-Verbose
    }

    Write-Verbose "===> Checking if any content exists inside of $targetVersionPath"

    $contentTargetVersionPath = Get-ChildItem -Path $targetVersionPath -Recurse -ErrorAction SilentlyContinue

    if ($null -eq $contentTargetVersionPath) {
        Write-Verbose "===> Pulling and extracting release $releaseTag into $targetVersionPath"
        New-Item -ItemType Directory -Path "$targetVersionPath/tmp" | Out-String | Write-Verbose
        $targetPathForZip = "$targetVersionPath/tmp/$releaseTag.zip"

        # Get the artifact url
        if($releaseArtifactName -ne "") {
            $releaseArtifactUrl = $releaseData.assets | Where-Object { $_.name -eq $releaseArtifactName } | Select-Object -ExpandProperty browser_download_url
        } else {
            $releaseArtifactUrl = $releaseData.zipball_url
        }

        Write-Verbose "===> Downloading the release artifact $releaseArtifactUrl from the GitHub repository $repoOrgPlusRepo"

        Invoke-WebRequest -Uri $releaseArtifactUrl -OutFile $targetPathForZip -RetryIntervalSec 3 -MaximumRetryCount 100 | Out-String | Write-Verbose

        if(!(Test-Path $targetPathForZip)) {
            Write-InformationColored "Failed to download the release $releaseTag from the GitHub repository $repoOrgPlusRepo" -ForegroundColor Red -InformationAction Continue
            throw
        }

        $targetPathForExtractedZip = "$targetVersionPath/tmp/extracted"

        Expand-Archive -Path $targetPathForZip -DestinationPath $targetPathForExtractedZip | Out-String | Write-Verbose

        $extractedSubFolder = $targetPathForExtractedZip
        if($releaseArtifactName -eq "") {
            $extractedSubFolder = (Get-ChildItem -Path $targetPathForExtractedZip -Directory).FullName
        }

        Write-Verbose "===> Copying all extracted contents into $targetVersionPath from $($extractedSubFolder)/$moduleSourceFolder/*."

        Copy-Item -Path "$($extractedSubFolder)/$moduleSourceFolder/*" -Destination "$targetVersionPath" -Recurse -Force | Out-String | Write-Verbose

        Remove-Item -Path "$targetVersionPath/tmp" -Force -Recurse
        Write-InformationColored "The directory for $targetVersionPath has been created and populated." -ForegroundColor Green -InformationAction Continue
    } else {
        Write-InformationColored "The directory for $targetVersionPath already exists and has content in it, so we are not overwriting it." -ForegroundColor Green -InformationAction Continue
        Write-Verbose "===> Content already exists in $releaseDirectory. Skipping"
    }

    # Check and replace the .env file release version if it is Bicep
    $envFilePath = Join-Path -Path $parentDirectory -ChildPath ".env"
    if (Test-Path $envFilePath) {
        Write-Verbose "===> Replacing the .env file release version with $releaseTag"
        (Get-Content $envFilePath) -replace "UPSTREAM_RELEASE_VERSION=.*", "UPSTREAM_RELEASE_VERSION=$releaseTag" | Set-Content $envFilePath
    }

    return $releaseTag
}
