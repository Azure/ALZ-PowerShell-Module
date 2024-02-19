function New-FolderStructure {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $targetDirectory,

        [Parameter(Mandatory = $false, HelpMessage = "The directory location of the bootstrap modules.")]
        [sting] $bootstrapModuleSourceFolder = "bootstrap",

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

        [Parameter(Mandatory = $false, HelpMessage = "Used to override the bootstrap folder location.")]
        $bootstrapModuleOverrideFolderPath = "",

        [Parameter(Mandatory = $false, HelpMessage = "Used to override the starter folder location.")]
        $starterModuleOverrideFolderPath = ""
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {
        Write-InformationColored "Checking you have the latest version of Terraform installed..." -ForegroundColor Green -InformationAction Continue
        $toolsPath = Join-Path -Path $targetFolder -ChildPath ".tools"
        Get-TerraformTool -version "latest" -toolsPath $toolsPath

        Write-InformationColored "Downloading modules to $targetDirectory" -ForegroundColor Green -InformationAction Continue

        # Downloading the latest or specified version of the modules
        if(!($bootstrapVersion.StartsWith("v")) -and ($bootstrapVersion -ne "latest")) {
            $bootstrapVersion = "v$bootstrapVersion"
        }
        if(!($starterVersion.StartsWith("v")) -and ($starterVersion -ne "latest")) {
            $starterVersion = "v$starterVersion"
        }

        $bootstrapTargetFolder = "bootstrap"
        $starterTargetFolder = "starter"

        $bootstrapReleaseTag = "overridden"
        $starterReleaseTag = "overridden"

        if($bootstrapModuleOverrideFolderPath -eq "") {
            $bootstrapReleaseTag = Get-GithubRelease -githubRepoUrl $boostrapUrl -targetDirectory $targetDirectory -moduleSourceFolder $bootstrapModuleSourceFolder -moduleTargetFolder $bootstrapTargetFolder -version $bootstrapVersion
        }
        if(starterModuleOverrideFolderPath -eq "") {
            $starterReleaseTag = Get-GithubRelease -githubRepoUrl $starterUrl -targetDirectory $targetDirectory -moduleSourceFolder $starterModuleSourceFolder -moduleTargetFolder $starterTargetFolder -version $starterVersion
        }

        # Run upgrade
        Invoke-Upgrade -alzEnvironmentDestination $alzEnvironmentDestination -bootstrapCacheFileName $bootstrapCacheFileName -starterCacheFileNamePattern $starterCacheFileNamePattern -stateFilePathAndFileName "bootstrap/$alzCicdPlatform/terraform.tfstate" -currentVersion $releaseTag -autoApprove:$autoApprove.IsPresent

        Write-InformationColored "Got downloaded module version $releaseTag to $targetDirectory" -ForegroundColor Green -InformationAction Continue

        return @{
            bootstrapPath       = Path-Join $targetDirectory $bootstrapTargetFolder $bootstrapReleaseTag
            starterPath         = Path-Join $targetDirectory $starterTargetFolder $starterReleaseTag
            bootstrapReleaseTag = $bootstrapReleaseTag
            starterReleaseTag   = $starterReleaseTag
        }
    }
}