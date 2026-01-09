####################################
# Get-GithubReleaseTag.ps1 #
####################################
# Version: 0.1.0

<#
.SYNOPSIS
Gets the release tag for a GitHub repository release.
.DESCRIPTION
Queries the GitHub API to get the release tag for a specific release or the latest release of a repository.

.EXAMPLE
Get-GithubReleaseTag -githubRepoUrl "https://github.com/Azure/accelerator-bootstrap-modules" -release "latest"

.EXAMPLE
Get-GithubReleaseTag -githubRepoUrl "https://github.com/Azure/accelerator-bootstrap-modules" -release "v1.0.0"

.NOTES
# Release notes 09/01/2026 - V0.1.0:
- Initial release - extracted from Get-GithubRelease.ps1.
#>

function Get-GithubReleaseTag {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Please provide the full URL of the GitHub repository you wish to check for the release.")]
        [string]
        $githubRepoUrl,

        [Parameter(Mandatory = $false, Position = 2, HelpMessage = "The release to check. Specify 'latest' to get the latest release tag. Defaults to 'latest'.")]
        [string]
        $release = "latest"
    )

    # Split Repo URL into parts
    $repoOrgPlusRepo = $githubRepoUrl.Split("/")[-2..-1] -join "/"

    Write-Verbose "=====> Checking for release on GitHub Repo: $repoOrgPlusRepo"

    # Build the API URL
    $repoReleaseUrl = "https://api.github.com/repos/$repoOrgPlusRepo/releases/$release"
    if ($release -ne "latest") {
        $repoReleaseUrl = "https://api.github.com/repos/$repoOrgPlusRepo/releases/tags/$release"
    }

    # Query the GitHub API
    $releaseData = Invoke-RestMethod $repoReleaseUrl -SkipHttpErrorCheck -StatusCodeVariable "statusCode"

    Write-Verbose "Status code: $statusCode"

    if ($statusCode -eq 404) {
        Write-Error "The release $release does not exist in the GitHub repository $githubRepoUrl - $repoReleaseUrl"
        throw "The release $release does not exist in the GitHub repository $githubRepoUrl - $repoReleaseUrl"
    }

    # Handle transient errors like throttling
    if ($statusCode -ge 400 -and $statusCode -le 599) {
        Write-InformationColored "Retrying as got the Status Code $statusCode, which may be a transient error." -ForegroundColor Yellow -InformationAction Continue
        $releaseData = Invoke-RestMethod $repoReleaseUrl -RetryIntervalSec 3 -MaximumRetryCount 100
    }

    if ($statusCode -ne 200) {
        throw "Unable to query repository version, please check your internet connection and try again..."
    }

    return @{
        ReleaseTag  = $releaseData.tag_name
        ReleaseData = $releaseData
    }
}
