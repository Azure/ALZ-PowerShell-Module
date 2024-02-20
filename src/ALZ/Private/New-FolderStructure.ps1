function New-FolderStructure {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $targetDirectory,

        [Parameter(Mandatory = $true)]
        [string] $url,

        [Parameter(Mandatory = $false)]
        [string] $release = "latest",

        [Parameter(Mandatory = $true)]
        [string] $targetFolder,

        [Parameter(Mandatory = $false)]
        [string] $sourceFolder
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {
        $ProgressPreference = "SilentlyContinue"

        Write-InformationColored "Downloading modules to $targetDirectory" -ForegroundColor Green -InformationAction Continue

        if(!($release.StartsWith("v")) -and ($release -ne "latest")) {
            $release = "v$release"
        }

        $releaseTag = Get-GithubRelease -githubRepoUrl $yrl -targetDirectory $targetDirectory -moduleSourceFolder $sourceFolder -moduleTargetFolder $targetFolder -release $release
        $path = Join-Path $targetDirectory $targetFolder $releaseTag

        Write-InformationColored "Downloaded module version $releaseTag to $path" -ForegroundColor Green -InformationAction Continue

        $ProgressPreference = "Continue"

        return @{
            path       = $path
            releaseTag = $releaseTag
        }
    }
}