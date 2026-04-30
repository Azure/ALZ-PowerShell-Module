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

        [Parameter(Mandatory = $false, Position = 2, HelpMessage = "The release to download. Specify 'latest' to download the latest release. Defaults to the latest release.")]
        [string]
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
        $releaseArtifactName = "",

        [Parameter(Mandatory = $false, HelpMessage = "Maximum number of retries for transient GitHub API errors.")]
        [int]
        $maxRetryCount = 10,

        [Parameter(Mandatory = $false, HelpMessage = "Seconds to wait between retries for transient HTTP request errors.")]
        [int]
        $retryIntervalSeconds = 3,

        [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds for HTTP requests.")]
        [int]
        $httpRequestTimeoutSeconds
    )

    $parentDirectory = $targetDirectory
    $targetPath = Join-Path $targetDirectory $moduleTargetFolder

    # Get the release tag and data from GitHub
    $releaseTagParams = @{
        githubRepoUrl        = $githubRepoUrl
        release              = $release
        maxRetryCount        = $maxRetryCount
        retryIntervalSeconds = $retryIntervalSeconds
    }
    if ($PSBoundParameters.ContainsKey("httpRequestTimeoutSeconds")) {
        $releaseTagParams["httpRequestTimeoutSeconds"] = $httpRequestTimeoutSeconds
    }
    $releaseResult = Get-GithubReleaseTag @releaseTagParams
    $releaseTag = $releaseResult.ReleaseTag
    $releaseData = $releaseResult.ReleaseData

    if ($queryOnly) {
        return $releaseTag
    }

    # Determine the target version path (do not create it yet - we only create it after a successful download/extract)
    $targetVersionPath = Join-Path $targetPath $releaseTag

    Write-Verbose "===> Checking if directory for release version exists: $targetVersionPath"

    $contentTargetVersionPath = $null
    if (Test-Path $targetVersionPath) {
        $contentTargetVersionPath = Get-ChildItem -Path $targetVersionPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($null -eq $contentTargetVersionPath) {
        # Stage the download and extraction in a temp location under the outputs folder so a failure
        # does not leave behind empty release/version folders. We always clean it up in `finally`.
        $stagingRoot = Join-Path $targetDirectory "temp/downloads/$([System.Guid]::NewGuid().ToString("N"))"
        New-Item -ItemType Directory -Path $stagingRoot -Force | Out-String | Write-Verbose
        $targetPathForZip = Join-Path $stagingRoot "$releaseTag.zip"
        $targetPathForExtractedZip = Join-Path $stagingRoot "extracted"

        try {
            # Get the artifact url
            if($releaseArtifactName -ne "") {
                $releaseArtifactUrl = $releaseData.assets | Where-Object { $_.name -eq $releaseArtifactName } | Select-Object -ExpandProperty browser_download_url
            } else {
                $releaseArtifactUrl = $releaseData.zipball_url
            }

            Write-Verbose "===> Downloading the release artifact $releaseArtifactUrl from the GitHub repository $repoOrgPlusRepo to staging location $targetPathForZip"

            $downloadParams = @{
                Uri                  = $releaseArtifactUrl
                OutputFile           = $targetPathForZip
                MaxRetryCount        = $maxRetryCount
                RetryIntervalSeconds = $retryIntervalSeconds
            }
            if ($PSBoundParameters.ContainsKey("httpRequestTimeoutSeconds")) {
                $downloadParams["TimeoutSec"] = $httpRequestTimeoutSeconds
            }
            Invoke-GitHubApiRequest @downloadParams

            if(!(Test-Path $targetPathForZip)) {
                Write-ToConsoleLog "Failed to download the release $releaseTag from the GitHub repository $repoOrgPlusRepo" -IsError
                throw "Failed to download the release $releaseTag from the GitHub repository $repoOrgPlusRepo"
            }

            Expand-Archive -Path $targetPathForZip -DestinationPath $targetPathForExtractedZip | Out-String | Write-Verbose

            $extractedSubFolder = $targetPathForExtractedZip
            if($releaseArtifactName -eq "") {
                $extractedSubFolder = (Get-ChildItem -Path $targetPathForExtractedZip -Directory -Force).FullName
            }

            # Only now (after a successful download and extract) do we create the target folders
            # and copy the content in.
            if (!(Test-Path $targetPath)) {
                Write-Verbose "Directory does not exist for releases, will now create: $targetPath"
                New-Item -ItemType Directory -Path $targetPath | Out-String | Write-Verbose
            }

            Write-Verbose "Directory does not exist for release $releaseTag, will now create: $targetVersionPath"
            New-Item -ItemType Directory -Path $targetVersionPath | Out-String | Write-Verbose

            Write-Verbose "===> Copying all extracted contents into $targetVersionPath from $($extractedSubFolder)/$moduleSourceFolder/*."

            Copy-Item -Path "$($extractedSubFolder)/$moduleSourceFolder/*" -Destination "$targetVersionPath" -Recurse -Force | Out-String | Write-Verbose

            Write-ToConsoleLog "The directory for $targetVersionPath has been created and populated." -IsSuccess
        } finally {
            if (Test-Path $stagingRoot) {
                Remove-Item -Path $stagingRoot -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
    } else {
        Write-ToConsoleLog "The directory for $targetVersionPath already exists and has content in it, so we are not overwriting it." -IsSuccess
        Write-Verbose "===> Content already exists in $releaseDirectory. Skipping"
    }

    # Check and replace the .env file release version if it is Bicep
    $envFilePath = Join-Path -Path $parentDirectory -ChildPath ".env"
    if (Test-Path $envFilePath) {
        Write-Verbose "===> Replacing the .env file release version with $releaseTag"
        (Get-Content $envFilePath -Force) -replace "UPSTREAM_RELEASE_VERSION=.*", "UPSTREAM_RELEASE_VERSION=$releaseTag" | Set-Content $envFilePath -Force
    }

    return $releaseTag
}
