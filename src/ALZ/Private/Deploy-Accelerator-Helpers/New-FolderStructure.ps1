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
        [string] $sourceFolder,

        [Parameter(Mandatory = $false)]
        [string] $overrideSourceDirectoryPath = ""
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {
        Write-Verbose "Downloading modules to $targetDirectory"

        if(!($release.StartsWith("v")) -and ($release -ne "latest")) {
            $release = "v$release"
        }

        $releaseTag = ""
        $path = ""

        if($overrideSourceDirectoryPath -ne "") {
            $releaseTag = "local"
            $path = Join-Path $targetDirectory $targetFolder $releaseTag

            if(Test-Path $path) {
                Write-Verbose "Folder $path already exists, so not copying files."
            } else {
                Write-InformationColored "Copying files from $overrideSourceDirectoryPath to $path" -ForegroundColor Green -InformationAction Continue
                New-Item -Path $path -ItemType "Directory"
                Copy-Item -Path "$overrideSourceDirectoryPath/$sourceFolder/*" -Destination "$path" -Recurse -Force | Out-String | Write-Verbose
            }

        } else {
            $releaseTag = Get-GithubRelease -githubRepoUrl $url -targetDirectory $targetDirectory -moduleSourceFolder $sourceFolder -moduleTargetFolder $targetFolder -release $release
            $path = Join-Path $targetDirectory $targetFolder $releaseTag
        }

        Write-Verbose "Version $releaseTag is located in $path"

        return @{
            path       = $path
            releaseTag = $releaseTag
        }
    }
}