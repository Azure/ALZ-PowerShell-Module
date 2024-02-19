function New-FolderStructure {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $targetDirectory,

        [Parameter(Mandatory = $false, HelpMessage = "The directory location of the bootstrap modules.")]
        [string] $bootstrapModuleSourceFolder = "bootstrap",

        [Parameter(Mandatory = $false, HelpMessage = "The directory location of the starter modules.")]
        [string] $starterModuleSourceFolder = "",

        [Parameter(Mandatory = $true)]
        [string] $bootstrapUrl,

        [Parameter(Mandatory = $true)]
        [string] $starterUrl,

        [Parameter(Mandatory = $false)]
        [string] $bootstrapVersion = "latest",

        [Parameter(Mandatory = $false)]
        [string] $starterVersion = "latest",

        [Parameter(Mandatory = $false)]
        [string]
        $bootstrapTargetFolder = "bootstrap",

        [Parameter(Mandatory = $true)]
        [string]
        $starterTargetFolder,

        [Parameter(Mandatory = $false, HelpMessage = "Used to override the bootstrap folder location.")]
        [string] $bootstrapModuleOverrideFolderPath = "",

        [Parameter(Mandatory = $false, HelpMessage = "Used to override the starter folder location.")]
        [string] $starterModuleOverrideFolderPath = ""
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {
        $ProgressPreference = "SilentlyContinue"

        Write-InformationColored "Checking you have the latest version of Terraform installed..." -ForegroundColor Green -InformationAction Continue
        $toolsPath = Join-Path -Path $targetDirectory -ChildPath ".tools"
        Get-TerraformTool -version "latest" -toolsPath $toolsPath

        Write-InformationColored "Downloading modules to $targetDirectory" -ForegroundColor Green -InformationAction Continue

        # Downloading the latest or specified version of the modules
        if(!($bootstrapVersion.StartsWith("v")) -and ($bootstrapVersion -ne "latest")) {
            $bootstrapVersion = "v$bootstrapVersion"
        }
        if(!($starterVersion.StartsWith("v")) -and ($starterVersion -ne "latest")) {
            $starterVersion = "v$starterVersion"
        }

        $bootstrapReleaseTag = "overridden"
        $starterReleaseTag = "overridden"

        $bootstrapPath = $bootstrapModuleOverrideFolderPath
        $starterPath = $starterModuleOverrideFolderPath

        if($bootstrapModuleOverrideFolderPath -eq "") {
            $bootstrapReleaseTag = Get-GithubRelease -githubRepoUrl $bootstrapUrl -targetDirectory $targetDirectory -moduleSourceFolder $bootstrapModuleSourceFolder -moduleTargetFolder $bootstrapTargetFolder -release $bootstrapVersion
            $bootstrapPath = Join-Path $targetDirectory $bootstrapTargetFolder $bootstrapReleaseTag
        }
        if($starterModuleOverrideFolderPath -eq "") {
            $starterReleaseTag = Get-GithubRelease -githubRepoUrl $starterUrl -targetDirectory $targetDirectory -moduleSourceFolder $starterModuleSourceFolder -moduleTargetFolder $starterTargetFolder -release $starterVersion
            $starterPath = Join-Path $targetDirectory $starterTargetFolder $starterReleaseTag
        }

        # Run upgrade
        Invoke-Upgrade -alzEnvironmentDestination $alzEnvironmentDestination -bootstrapCacheFileName $bootstrapCacheFileName -starterCacheFileNamePattern $starterCacheFileNamePattern -stateFilePathAndFileName "bootstrap/$alzCicdPlatform/terraform.tfstate" -currentVersion $releaseTag -autoApprove:$autoApprove.IsPresent

        Write-InformationColored "Downloaded bootstrap module version $bootstrapReleaseTag to $bootstrapPath" -ForegroundColor Green -InformationAction Continue
        Write-InformationColored "Downloaded starter module version $starterReleaseTag to $starterPath" -ForegroundColor Green -InformationAction Continue

        $ProgressPreference = "Continue"

        return @{
            bootstrapPath       = $bootstrapPath
            starterPath         = $starterPath
            bootstrapReleaseTag = $bootstrapReleaseTag
            starterReleaseTag   = $starterReleaseTag
        }
    }
}