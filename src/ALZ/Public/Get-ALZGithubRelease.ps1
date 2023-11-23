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
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The IaC provider to use for the ALZ environment.")]
        [ValidateSet("bicep", "terraform")]
        [Alias("Iac")]
        [Alias("i")]
        [string]
        $alzIacProvider,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Please the provide the full URL of the GitHub repository you wish to check for the latest release.")]
        [string]
        $githubRepoUrl = "",

        [Parameter(Mandatory = $false, Position = 2, HelpMessage = "The releases to download. Specify 'all' to download all releases or 'latest' to download the latest release. Defaults to the latest release.")]
        [array]
        [Alias("version")]
        [Alias("v")]
        $release = "latest",

        [Parameter(Mandatory = $false, Position = 3, HelpMessage = "The directory to download the releases to. Defaults to the current directory.")]
        [string]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        $directoryForReleases = "$PWD/releases",

        [Parameter(Mandatory = $false, Position = 4, HelpMessage = "An array of strings contianing the paths to the directories or files that you wish to keep when downloading and extracting from the releases.")]
        [array]
        $directoryAndFilesToKeep = $null,

        [Parameter(Mandatory = $false, Position = 4, HelpMessage = "Whether to just query the API and return the release versions.")]
        [switch]
        $queryOnly
    )

    # Set the repository URL if not provided
    $bicepModuleUrl = "https://github.com/Azure/ALZ-Bicep"
    $terraformModuleUrl = "https://github.com/Azure/alz-terraform-accelerator"
    if($githubRepoUrl -eq "") {
        if($alzIacProvider -eq "bicep") {
            $githubRepoUrl = $bicepModuleUrl
        } elseif($alzIacProvider -eq "terraform") {
            $githubRepoUrl = $terraformModuleUrl
        }
    }

    $parentDirectory = $directoryForReleases
    # Bicep specific path setup
    if($alzIacProvider -eq "bicep") {
        $directoryForReleases = Join-Path $directoryForReleases "upstream-releases"
    }

    # Split Repo URL into parts
    $repoOrgPlusRepo = $githubRepoUrl.Split("/")[-2..-1] -join "/"

    Write-Verbose "=====> Checking for release on GitHub Repo: $repoOrgPlusRepo"

    # Get releases on repo
    $repoReleaseUrl = "https://api.github.com/repos/$repoOrgPlusRepo/releases/$release"
    if($release -ne "latest") {
        $repoReleaseUrl = "https://api.github.com/repos/$repoOrgPlusRepo/releases/tags/$release"
    }

    $releaseData = Invoke-RestMethod $repoReleaseUrl -SkipHttpErrorCheck -StatusCodeVariable "statusCode"

    if($statusCode -eq 404) {
        Write-Error "The release $release does not exist in the GitHub repository $githubRepoUrl - $repoReleaseUrl"
        throw "The release $release does not exist in the GitHub repository $githubRepoUrl - $repoReleaseUrl"
    }

    # Handle transient errors like throttling
    if($statusCode -ge 400 -and $statusCode -le 599) {
        Write-InformationColored "Retrying as got the Status Code $statusCode, which may be a tranisent error." -ForegroundColor Yellow -InformationAction Continue
        $releaseData = Invoke-RestMethod $repoReleaseUrl -RetryIntervalSec 3 -MaximumRetryCount 100
    }

    $releaseTag = $releaseData.tag_name

    if($queryOnly) {
        return $releaseTag
    }

    # Check if directory exists
    Write-Verbose "=====> Checking if directory for releases exists: $directoryForReleases"

    if (!(Test-Path $directoryForReleases)) {
        Write-Verbose "Directory does not exist for releases, will now create: $directoryForReleases"
        New-Item -ItemType Directory -Path $directoryForReleases | Out-String | Write-Verbose
    }

    # Check the directory for this release
    $releaseDirectory = "$directoryForReleases/$releaseTag"

    Write-Verbose "===> Checking if directory for release version exists: $releaseDirectory"

    if (!(Test-Path $releaseDirectory)) {
        Write-Verbose "Directory does not exist for release $releaseTag, will now create: $releaseDirectory"
        New-Item -ItemType Directory -Path $releaseDirectory | Out-String | Write-Verbose
    }

    Write-Verbose "===> Checking if any content exists inside of $releaseDirectory"

    $contentInReleaseDirectory = Get-ChildItem -Path $releaseDirectory -Recurse -ErrorAction SilentlyContinue

    if ($null -eq $contentInReleaseDirectory) {
        Write-Verbose "===> Pulling and extracting release $releaseTag into $releaseDirectory"
        New-Item -ItemType Directory -Path "$releaseDirectory/tmp" | Out-String | Write-Verbose
        Invoke-WebRequest -Uri "https://github.com/$repoOrgPlusRepo/archive/refs/tags/$releaseTag.zip" -OutFile "$releaseDirectory/tmp/$releaseTag.zip" -RetryIntervalSec 3 -MaximumRetryCount 100 | Out-String | Write-Verbose
        Expand-Archive -Path "$releaseDirectory/tmp/$releaseTag.zip" -DestinationPath "$releaseDirectory/tmp/extracted" | Out-String | Write-Verbose
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
        Write-InformationColored "The release directory for this version already exists and has content in it, so we are not over-writing it." -ForegroundColor Yellow -InformationAction Continue
        Write-Verbose "===> Content already exists in $releaseDirectory. Skipping"
    }

    # Check and replace the .env file release version if it is Bicep
    if($alzIacProvider -eq "bicep") {
        $envFilePath = Join-Path -Path $parentDirectory -ChildPath ".env"
        if(Test-Path $envFilePath) {
            Write-Verbose "===> Replacing the .env file release version with $releaseTag"
            (Get-Content $envFilePath) -replace "UPSTREAM_RELEASE_VERSION=.*", "UPSTREAM_RELEASE_VERSION=$releaseTag" | Set-Content $envFilePath
        }
    }

    return $releaseTag
}