function Request-AcceleratorConfigurationInput {
    <#
    .SYNOPSIS
    Prompts the user for accelerator configuration input and creates the folder structure.
    .DESCRIPTION
    This function interactively prompts the user for the inputs needed to set up the accelerator folder structure,
    calls New-AcceleratorFolderStructure to create the folders and configuration files, and returns the paths
    needed for Deploy-Accelerator to continue.
    .PARAMETER Destroy
    When set, only prompts for the target folder path and validates the existing folder structure exists.
    .OUTPUTS
    Returns a hashtable with the following keys:
    - Continue: Boolean indicating whether to continue with deployment
    - InputConfigFilePaths: Array of input configuration file paths
    - StarterAdditionalFiles: Array of additional files/folders for the starter module
    - OutputFolderPath: Path to the output folder
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [switch] $Destroy
    )

    if ($PSCmdlet.ShouldProcess("Accelerator folder structure setup", "prompt and create")) {
        # Display appropriate header message
        if ($Destroy.IsPresent) {
            Write-InformationColored "Running in destroy mode. Please provide the path to your existing accelerator folder." -ForegroundColor Yellow -NewLineBefore -InformationAction Continue
        } else {
            Write-InformationColored "No input configuration files provided. Let's set up the accelerator folder structure first..." -ForegroundColor Green -NewLineBefore -InformationAction Continue
            Write-InformationColored "For more information, see: https://aka.ms/alz/acc/phase2" -ForegroundColor Cyan -InformationAction Continue
        }

        # Prompt for target folder path (first prompt for both modes)
        Write-InformationColored "`nEnter the target folder path for the accelerator files (default: ~/accelerator):" -ForegroundColor Yellow -InformationAction Continue
        $targetFolderPathInput = Read-Host "Target folder path"
        if ([string]::IsNullOrWhiteSpace($targetFolderPathInput)) {
            $targetFolderPathInput = "~/accelerator"
        }

        # Normalize the path
        $normalizedTargetPath = Get-NormalizedPath -Path $targetFolderPathInput

        # Analyze existing folder configuration
        $folderConfig = Get-AcceleratorFolderConfiguration -FolderPath $normalizedTargetPath
        $useExistingFolder = $false
        $forceFlag = $false

        # If folder exists, ask about overwriting before other prompts
        if ($folderConfig.FolderExists) {
            # Ask about overwriting the folder
            Write-InformationColored "`nTarget folder '$normalizedTargetPath' already exists." -ForegroundColor Yellow -InformationAction Continue
            $forceResponse = Read-Host "Do you want to overwrite it? (y/N)"
            if ($forceResponse -eq "y" -or $forceResponse -eq "Y") {
                $forceFlag = $true
            } else {
                # User wants to keep existing folder
                $useExistingFolder = $true

                # Validate config files exist
                if (-not $folderConfig.IsValid) {
                    if (-not (Test-Path -Path $folderConfig.ConfigFolderPath)) {
                        Write-InformationColored "ERROR: Config folder not found at '$($folderConfig.ConfigFolderPath)'" -ForegroundColor Red -InformationAction Continue
                    } elseif (-not (Test-Path -Path $folderConfig.InputsYamlPath)) {
                        Write-InformationColored "ERROR: Required configuration file not found: inputs.yaml" -ForegroundColor Red -InformationAction Continue
                    }
                    Write-InformationColored "Please overwrite the folder structure by choosing 'y', or run New-AcceleratorFolderStructure manually." -ForegroundColor Yellow -InformationAction Continue
                    return ConvertTo-AcceleratorResult -Continue $false
                }
            }
        }

        # Handle destroy mode - validate existing folder and return early
        if ($Destroy.IsPresent) {
            if (-not $folderConfig.FolderExists) {
                Write-InformationColored "ERROR: Target folder '$normalizedTargetPath' does not exist." -ForegroundColor Red -InformationAction Continue
                Write-InformationColored "Cannot destroy a deployment that doesn't exist. Please check the path and try again." -ForegroundColor Yellow -InformationAction Continue
                return ConvertTo-AcceleratorResult -Continue $false
            }

            if (-not (Test-Path -Path $folderConfig.ConfigFolderPath)) {
                Write-InformationColored "ERROR: Config folder not found at '$($folderConfig.ConfigFolderPath)'" -ForegroundColor Red -InformationAction Continue
                Write-InformationColored "Cannot destroy a deployment without configuration files." -ForegroundColor Yellow -InformationAction Continue
                return ConvertTo-AcceleratorResult -Continue $false
            }

            if (-not (Test-Path -Path $folderConfig.InputsYamlPath)) {
                Write-InformationColored "ERROR: Required configuration file not found: inputs.yaml" -ForegroundColor Red -InformationAction Continue
                Write-InformationColored "Cannot destroy a deployment without inputs.yaml." -ForegroundColor Yellow -InformationAction Continue
                return ConvertTo-AcceleratorResult -Continue $false
            }

            # Build input config file paths based on detected IaC type
            $configPaths = Get-AcceleratorConfigPath -IacType $folderConfig.IacType -ConfigFolderPath $folderConfig.ConfigFolderPath
            $resolvedTargetPath = (Resolve-Path -Path $normalizedTargetPath).Path

            Write-InformationColored "Using existing folder: $resolvedTargetPath" -ForegroundColor Green -InformationAction Continue
            Write-InformationColored "`nProceeding with destroy..." -ForegroundColor Yellow -InformationAction Continue

            return ConvertTo-AcceleratorResult -Continue $true `
                -InputConfigFilePaths $configPaths.InputConfigFilePaths `
                -StarterAdditionalFiles $configPaths.StarterAdditionalFiles `
                -OutputFolderPath "$resolvedTargetPath/output"
        }

        # Set selected values from detected values (for use existing folder case)
        $selectedIacType = $folderConfig.IacType
        $selectedVersionControl = $folderConfig.VersionControl
        $selectedScenarioNumber = 1

        # Only prompt for IaC type, version control, and scenario if creating new folder or overwriting
        if (-not $useExistingFolder) {
            # Prompt for IaC type with detected value as default
            $iacTypeOptions = @("terraform", "bicep")
            $defaultIacTypeIndex = if ($null -ne $folderConfig.IacType) {
                [Math]::Max(0, $iacTypeOptions.IndexOf($folderConfig.IacType))
            } else { 0 }

            $selectedIacType = Read-MenuSelection `
                -Title "`nSelect the Infrastructure as Code (IaC) type:" `
                -Options $iacTypeOptions `
                -DefaultIndex $defaultIacTypeIndex

            # Prompt for version control with detected value as default
            $versionControlOptions = @("github", "azure-devops", "local")
            $defaultVcsIndex = if ($null -ne $folderConfig.VersionControl) {
                [Math]::Max(0, $versionControlOptions.IndexOf($folderConfig.VersionControl))
            } else { 0 }

            $selectedVersionControl = Read-MenuSelection `
                -Title "`nSelect the Version Control System:" `
                -Options $versionControlOptions `
                -DefaultIndex $defaultVcsIndex

            # Prompt for scenario number (Terraform only)
            if ($selectedIacType -eq "terraform") {
                $scenarioDescriptions = @(
                    "Full Multi-Region - Hub and Spoke VNet",
                    "Full Multi-Region - Virtual WAN",
                    "Full Multi-Region NVA - Hub and Spoke VNet",
                    "Full Multi-Region NVA - Virtual WAN",
                    "Management Only",
                    "Full Single-Region - Hub and Spoke VNet",
                    "Full Single-Region - Virtual WAN",
                    "Full Single-Region NVA - Hub and Spoke VNet",
                    "Full Single-Region NVA - Virtual WAN"
                )
                $scenarioNumbers = 1..$scenarioDescriptions.Count

                $selectedScenarioNumber = Read-MenuSelection `
                    -Title "`nSelect the Terraform scenario (see https://aka.ms/alz/acc/scenarios):" `
                    -Options $scenarioNumbers `
                    -OptionDescriptions $scenarioDescriptions `
                    -DefaultIndex 0
            }
        }

        # Create folder structure if needed
        if (-not $folderConfig.FolderExists -or $forceFlag) {
            New-AcceleratorFolderStructure `
                -iacType $selectedIacType `
                -versionControl $selectedVersionControl `
                -scenarioNumber $selectedScenarioNumber `
                -targetFolderPath $targetFolderPathInput `
                -force:$forceFlag

            Write-InformationColored "`nFolder structure created at: $normalizedTargetPath" -ForegroundColor Green -InformationAction Continue
        }

        # Resolve the path after folder creation or validation
        $resolvedTargetPath = (Resolve-Path -Path $normalizedTargetPath).Path
        $configFolderPath = if ($useExistingFolder) {
            $folderConfig.ConfigFolderPath
        } else {
            Join-Path $resolvedTargetPath "config"
        }

        if ($useExistingFolder) {
            Write-InformationColored "`nUsing existing folder structure at: $resolvedTargetPath" -ForegroundColor Green -InformationAction Continue
        }
        Write-InformationColored "Config folder: $configFolderPath" -ForegroundColor Cyan -InformationAction Continue

        # Offer to configure inputs interactively (default is Yes)
        $configureNowResponse = Read-Host "`nWould you like to configure the input values interactively now? (Y/n)"
        if ($configureNowResponse -ne "n" -and $configureNowResponse -ne "N") {
            $azureContext = Get-AzureContext

            Request-ALZConfigurationValue `
                -ConfigFolderPath $configFolderPath `
                -IacType $selectedIacType `
                -VersionControl $selectedVersionControl `
                -AzureContext $azureContext
        }

        # Check for VS Code or VS Code Insiders and offer to open the config folder
        $vsCodeCommand = $null
        $vsCodeName = $null

        if (Get-Command "code-insiders" -ErrorAction SilentlyContinue) {
            $vsCodeCommand = "code-insiders"
            $vsCodeName    = "VS Code Insiders"
        } elseif (Get-Command "code" -ErrorAction SilentlyContinue) {
            $vsCodeCommand = "code"
            $vsCodeName    = "VS Code"
        }

        if ($null -ne $vsCodeCommand) {
            $openInVsCodeResponse = Read-Host "`nWould you like to open the config folder in $($vsCodeName)? (Y/n)"
            if ($openInVsCodeResponse -ne "n" -and $openInVsCodeResponse -ne "N") {
                Write-InformationColored "Opening config folder in $vsCodeName..." -ForegroundColor Green -InformationAction Continue
                & $vsCodeCommand $configFolderPath
            }
        }

        Write-InformationColored "`nPlease check and update the configuration files in the config folder before continuing:" -ForegroundColor Yellow -InformationAction Continue
        Write-InformationColored "  - inputs.yaml: Bootstrap configuration (required)" -ForegroundColor White -InformationAction Continue

        if ($selectedIacType -eq "terraform") {
            Write-InformationColored "  - platform-landing-zone.tfvars: Platform configuration (required)" -ForegroundColor White -InformationAction Continue
            Write-InformationColored "    - starter_locations: Enter the regions for you platform landing zone (required)" -ForegroundColor White -InformationAction Continue
            Write-InformationColored "    - defender_email_security_contact: Enter the email security contact for Microsoft Defender for Cloud (required)" -ForegroundColor White -InformationAction Continue
            Write-InformationColored "  - lib/: Library customizations (optional)" -ForegroundColor White -InformationAction Continue
        } elseif ($selectedIacType -eq "bicep") {
            Write-InformationColored "  - platform-landing-zone.yaml: Platform configuration (required)" -ForegroundColor White -InformationAction Continue
            Write-InformationColored "    - starter_locations: Enter the regions for you platform landing zone (required)" -ForegroundColor White -InformationAction Continue
        }

        Write-InformationColored "`nFor more details, see: https://azure.github.io/Azure-Landing-Zones/accelerator/configuration-files/" -ForegroundColor Cyan -InformationAction Continue

        # Prompt to continue or exit
        $continueResponse = Read-Host "`nHave you checked and updated the configuration files? Enter 'yes' to continue with deployment, or 'no' to exit and configure later"
        if ($continueResponse -ne "yes") {
            Write-InformationColored "`nTo continue later, run Deploy-Accelerator with the following parameters:" -ForegroundColor Green -InformationAction Continue

            if ($selectedIacType -eq "terraform") {
                Write-InformationColored @"
Deploy-Accelerator ``
    -inputs "$configFolderPath/inputs.yaml", "$configFolderPath/platform-landing-zone.tfvars" ``
    -starterAdditionalFiles "$configFolderPath/lib" ``
    -output "$resolvedTargetPath/output"
"@ -ForegroundColor Cyan -InformationAction Continue
            } elseif ($selectedIacType -eq "bicep") {
                Write-InformationColored @"
Deploy-Accelerator ``
    -inputs "$configFolderPath/inputs.yaml", "$configFolderPath/platform-landing-zone.yaml" ``
    -output "$resolvedTargetPath/output"
"@ -ForegroundColor Cyan -InformationAction Continue
            } else {
                Write-InformationColored @"
Deploy-Accelerator ``
    -inputs "$configFolderPath/inputs.yaml" ``
    -output "$resolvedTargetPath/output"
"@ -ForegroundColor Cyan -InformationAction Continue
            }

            return ConvertTo-AcceleratorResult -Continue $false
        }

        # Build the result for continuing with deployment
        $configPaths = Get-AcceleratorConfigPath -IacType $selectedIacType -ConfigFolderPath $configFolderPath

        Write-InformationColored "`nContinuing with deployment..." -ForegroundColor Green -InformationAction Continue

        return ConvertTo-AcceleratorResult -Continue $true `
            -InputConfigFilePaths $configPaths.InputConfigFilePaths `
            -StarterAdditionalFiles $configPaths.StarterAdditionalFiles `
            -OutputFolderPath "$resolvedTargetPath/output"
    }
}
