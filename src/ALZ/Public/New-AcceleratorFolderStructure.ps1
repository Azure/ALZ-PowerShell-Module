function New-AcceleratorFolderStructure {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = "[REQUIRED] The infrastructure as code type for the accelerator. Options are 'terraform', 'bicep' or 'bicep-classic'"
        )]
        [string] $iacType = "terraform",
        [Parameter(
            Mandatory = $false,
            HelpMessage = "[REQUIRED] The version of the accelerator to use for the bootstrap and starter configuration files"
        )]
        [string] $versionControl = "github",
        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The scenario number to use for the starter configuration files"
        )]
        [int] $scenarioNumber = 1,
        [Parameter(
            Mandatory = $false,
            HelpMessage = "[REQUIRED] The target folder to create the accelerator bootstrap and platform landing zone configuration files in"
        )]
        [string] $targetFolderPath = "~/accelerator",
        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Forece recreate of the target folder if it already exists"
        )]
        [switch] $force
    )

    if ($PSCmdlet.ShouldProcess("Accelerator folder create", "modify")) {

        $currentPath = Get-Location

        # Normalize target folder path
        if($targetFolderPath.StartsWith("~/" )) {
            $targetFolderPath = Join-Path $HOME $targetFolderPath.Replace("~/", "")
        }
        if(Test-Path -Path $targetFolderPath) {
            if($force.IsPresent) {
                Write-Host "Force flag is set, removing existing target folder at $targetFolderPath"
                Remove-Item -Recurse -Force -Path $targetFolderPath | Write-Verbose | Out-Null
            } else {
                throw "Target folder $targetFolderPath already exists. Please specify a different folder path or remove the existing folder."
            }
        }
        Write-Host "Creating target folder at $targetFolderPath"
        New-Item -ItemType "directory" -Path $targetFolderPath -Force | Write-Verbose | Out-Null
        $targetFolderPath = (Resolve-Path -Path $targetFolderPath).Path

        # Create target folder structure
        $outputFolder = Join-Path $targetFolderPath "output"
        Write-Host "Creating output folder at $outputFolder"
        New-Item -ItemType "directory" $outputFolder -Force | Write-Verbose | Out-Null

        # Create temp folder
        $tempFolderPath = Join-Path $targetFolderPath "temp"
        Write-Host "Creating temp folder at $tempFolderPath"
        New-Item -ItemType "directory" $tempFolderPath -Force | Write-Verbose | Out-Null

        # Map the repo
        $repos = @{
            "terraform"     = @{
                repoName                   = "alz-terraform-accelerator"
                folderToClone              = "templates/platform_landing_zone"
                libraryFolderPath          = "lib"
                exampleFolderPath          = "examples"
                bootstrapExampleFolderPath = "bootstrap"
                hasScenarios               = $true
                hasLibrary                 = $true
            }

            "bicep"         = @{
                repoName                    = "alz-bicep-accelerator"
                folderToClone               = ""
                libraryFolderPath           = ""
                exampleFolderPath           = "examples"
                bootstrapExampleFolderPath  = "bootstrap"
                hasScenarios                = $false
                hasLibrary                  = $false
                platformLandingZoneFilePath = "platform-landing-zone.yaml"
            }

            "bicep-classic" = @{
                repoName                    = "alz-bicep"
                folderToClone               = "accelerator"
                libraryFolderPath           = ""
                exampleFolderPath           = "examples"
                bootstrapExampleFolderPath  = "bootstrap"
                hasScenarios                = $false
                hasLibrary                  = $false
                platformLandingZoneFilePath = ""
            }
        }

        # Clone the repo and copy the bootstrap and starter configuration files
        $repo = $repos[$iacType]
        Write-Host "Cloning repo $($repo.repoName)"
        git clone --depth=1 "https://github.com/Azure/$($repo.repoName)" "$tempFolderPath" | Write-Verbose | Out-Null
        Set-Location $tempFolderPath

        Set-Location $currentPath
        $exampleFolderPath = "$($repo.folderToClone)/$($repo.exampleFolderPath)"
        $bootstrapExampleFolderPath = "$exampleFolderPath/$($repo.bootstrapExampleFolderPath)"

        $configFolderPath = Join-Path $targetFolderPath "config"
        Write-Host "Creating config folder at $configFolderPath"
        New-Item -ItemType "directory" $configFolderPath -Force | Write-Verbose | Out-Null

        # Copy the bootstrap configuration file
        Write-Host "Copying bootstrap configuration file to $($targetFolderPath)/config/inputs.yaml"
        Copy-Item -Path "$tempFolderPath/$bootstrapExampleFolderPath/inputs-$versionControl.yaml" -Destination "$targetFolderPath/config/inputs.yaml" -Force | Write-Verbose | Out-Null

        if ($repo.hasLibrary) {
            $libFolderPath = "$($repo.folderToClone)/$($repo.libraryFolderPath)"
            Write-Host "Copying library files to $($targetFolderPath)/config"
            Copy-Item -Path "$tempFolderPath/$libFolderPath" -Destination "$targetFolderPath/config" -Recurse -Force | Write-Verbose | Out-Null
        }

        # Copy the platform landing zone configuration files based on scenario number or specific file path
        if ($repo.hasScenarios) {
            $scenarios = @{
                1 = "full-multi-region/hub-and-spoke-vnet.tfvars"
                2 = "full-multi-region/virtual-wan.tfvars"
                3 = "full-multi-region-nva/hub-and-spoke-vnet.tfvars"
                4 = "full-multi-region-nva/virtual-wan.tfvars"
                5 = "management-only/management.tfvars"
                6 = "full-single-region/hub-and-spoke-vnet.tfvars"
                7 = "full-single-region/virtual-wan.tfvars"
                8 = "full-single-region-nva/hub-and-spoke-vnet.tfvars"
                9 = "full-single-region-nva/virtual-wan.tfvars"
            }

            Write-Host "Copying platform landing zone configuration file for scenario $scenarioNumber to $($targetFolderPath)/config/platform-landing-zone.tfvars"
            Copy-Item -Path "$tempFolderPath/$exampleFolderPath/$($scenarios[$scenarioNumber])" -Destination "$targetFolderPath/config/platform-landing-zone.tfvars" -Force | Write-Verbose | Out-Null

        } elseif ($repo.platformLandingZoneFilePath -ne "") {
            Write-Host "Copying platform landing zone configuration file to $($targetFolderPath)/config/platform-landing-zone.yaml"
            Copy-Item -Path "$tempFolderPath/$exampleFolderPath/$($repo.platformLandingZoneFilePath)" -Destination "$targetFolderPath/config/platform-landing-zone.yaml" -Force | Write-Verbose | Out-Null
        }

        # Remove-Item -Path $tempFolderPath -Recurse -Force | Write-Verbose | Out-Null
    }
}
