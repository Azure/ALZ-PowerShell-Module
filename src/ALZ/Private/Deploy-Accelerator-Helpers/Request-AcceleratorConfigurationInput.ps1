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
        [switch] $Destroy,

        [Parameter(Mandatory = $false)]
        [switch] $ClearCache,

        [Parameter(Mandatory = $false)]
        [string] $OutputFolderName = "output"
    )

    if ($PSCmdlet.ShouldProcess("Accelerator folder structure setup", "prompt and create")) {

        # Display appropriate header message
        if ($Destroy.IsPresent) {
            Write-ToConsoleLog "Running in destroy mode. Please provide the path to your existing accelerator folder." -IsWarning
        } else {
            Write-ToConsoleLog "No input configuration files provided. Let's set up the accelerator folder structure first..." -IsSuccess
            Write-ToConsoleLog "For more information, see: https://aka.ms/alz/acc/phase2"
        }

        # Prompt for target folder path (first prompt for both modes)
        $targetFolderPathInput = Read-MenuSelection `
            -Title "Enter the target folder path for the accelerator files:" `
            -DefaultValue "~/accelerator" `
            -AllowManualEntry `
            -ManualEntryPrompt "Target folder path"

        # Normalize the path
        $normalizedTargetPath = Get-NormalizedPath -Path $targetFolderPathInput

        # Analyze existing folder configuration
        $folderConfig = Get-AcceleratorFolderConfiguration -FolderPath $normalizedTargetPath
        $useExistingFolder = $false
        $forceFlag = $false

        # If folder exists, ask about overwriting before other prompts
        if ($folderConfig.FolderExists) {
            # Ask about overwriting the folder
            Write-ToConsoleLog "Target folder '$normalizedTargetPath' already exists." -IsWarning
            $forceResponse = Read-MenuSelection `
                -Title "Do you want to overwrite the existing folder structure? This will replace existing configuration files." `
                -DefaultValue "no" `
                -Type "boolean" `
                -AllowManualEntry `
                -ManualEntryPrompt "Enter '[y]es' to overwrite or '[n]o' to keep existing"

            Write-Verbose "User overwrite response: $forceResponse"
            Write-Verbose $forceResponse.GetType().FullName

            if ($forceResponse) {
                $forceFlag = $true
            } else {
                # User wants to keep existing folder
                $useExistingFolder = $true

                # Validate config files exist
                if (-not $folderConfig.IsValid) {
                    if (-not (Test-Path -Path $folderConfig.ConfigFolderPath)) {
                        Write-ToConsoleLog "ERROR: Config folder not found at '$($folderConfig.ConfigFolderPath)'" -IsError
                    } elseif (-not (Test-Path -Path $folderConfig.InputsYamlPath)) {
                        Write-ToConsoleLog "ERROR: Required configuration file not found: inputs.yaml" -IsError
                    }
                    Write-ToConsoleLog "Please overwrite the folder structure by choosing 'y', or run New-AcceleratorFolderStructure manually." -IsWarning
                    return ConvertTo-AcceleratorResult -Continue $false
                }
            }
        }

        # Handle destroy mode - validate existing folder and return early
        if ($Destroy.IsPresent) {
            if (-not $folderConfig.FolderExists) {
                Write-ToConsoleLog "ERROR: Target folder '$normalizedTargetPath' does not exist." -IsError
                Write-ToConsoleLog "Cannot destroy a deployment that doesn't exist. Please check the path and try again." -IsWarning
                return ConvertTo-AcceleratorResult -Continue $false
            }

            if (-not (Test-Path -Path $folderConfig.ConfigFolderPath)) {
                Write-ToConsoleLog "ERROR: Config folder not found at '$($folderConfig.ConfigFolderPath)'" -IsError
                Write-ToConsoleLog "Cannot destroy a deployment without configuration files." -IsWarning
                return ConvertTo-AcceleratorResult -Continue $false
            }

            if (-not (Test-Path -Path $folderConfig.InputsYamlPath)) {
                Write-ToConsoleLog "ERROR: Required configuration file not found: inputs.yaml" -IsError
                Write-ToConsoleLog "Cannot destroy a deployment without inputs.yaml." -IsWarning
                return ConvertTo-AcceleratorResult -Continue $false
            }

            # Build input config file paths based on detected IaC type
            $configPaths = Get-AcceleratorConfigPath -IacType $folderConfig.IacType -ConfigFolderPath $folderConfig.ConfigFolderPath
            $resolvedTargetPath = (Resolve-Path -Path $normalizedTargetPath).Path

            Write-ToConsoleLog "Using existing folder: $resolvedTargetPath" -IsSuccess

            # Prompt for sensitive inputs that are not already set (e.g., PATs)
            Write-ToConsoleLog "Checking for sensitive inputs that need to be provided..." -IsWarning

            Request-ALZConfigurationValue `
                -ConfigFolderPath $folderConfig.ConfigFolderPath `
                -IacType $folderConfig.IacType `
                -VersionControl $folderConfig.VersionControl `
                -AzureContextOutputDirectory $folderConfig.OutputFolderPath `
                -AzureContextClearCache:$ClearCache.IsPresent `
                -SensitiveOnly

            Write-ToConsoleLog "Proceeding with destroy..." -IsWarning

            return ConvertTo-AcceleratorResult -Continue $true `
                -InputConfigFilePaths $configPaths.InputConfigFilePaths `
                -StarterAdditionalFiles $configPaths.StarterAdditionalFiles `
                -OutputFolderPath $folderConfig.OutputFolderPath
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
                -Title "Select the Infrastructure as Code (IaC) type:" `
                -Options $iacTypeOptions `
                -DefaultIndex $defaultIacTypeIndex

            # Prompt for version control with detected value as default
            $versionControlOptions = @("github", "azure-devops", "local")
            $defaultVcsIndex = if ($null -ne $folderConfig.VersionControl) {
                [Math]::Max(0, $versionControlOptions.IndexOf($folderConfig.VersionControl))
            } else { 0 }

            $selectedVersionControl = Read-MenuSelection `
                -Title "Select the Version Control System:" `
                -Options $versionControlOptions `
                -DefaultIndex $defaultVcsIndex

            # Prompt for scenario number (Terraform only)
            if ($selectedIacType -eq "terraform") {
                $scenarioOptions = @(
                    @{ label = "1 - Full Multi-Region - Hub and Spoke VNet"; value = 1 },
                    @{ label = "2 - Full Multi-Region - Virtual WAN"; value = 2 },
                    @{ label = "3 - Full Multi-Region NVA - Hub and Spoke VNet"; value = 3 },
                    @{ label = "4 - Full Multi-Region NVA - Virtual WAN"; value = 4 },
                    @{ label = "5 - Management Only"; value = 5 },
                    @{ label = "6 - Full Single-Region - Hub and Spoke VNet"; value = 6 },
                    @{ label = "7 - Full Single-Region - Virtual WAN"; value = 7 },
                    @{ label = "8 - Full Single-Region NVA - Hub and Spoke VNet"; value = 8 },
                    @{ label = "9 - Full Single-Region NVA - Virtual WAN"; value = 9 }
                )

                $selectedScenarioNumber = Read-MenuSelection `
                    -Title "Select the Terraform scenario (see https://aka.ms/alz/acc/scenarios):" `
                    -Options $scenarioOptions `
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
                -outputFolderName $OutputFolderName `
                -force:$forceFlag

            Write-ToConsoleLog "Folder structure created at: $normalizedTargetPath" -IsSuccess
        }

        # Resolve the path after folder creation or validation
        $resolvedTargetPath = (Resolve-Path -Path $normalizedTargetPath).Path
        $outputFolderPath = Join-Path $resolvedTargetPath $OutputFolderName
        $configFolderPath = if ($useExistingFolder) {
            $folderConfig.ConfigFolderPath
        } else {
            Join-Path $resolvedTargetPath "config"
        }

        if ($useExistingFolder) {
            Write-ToConsoleLog "Using existing folder structure at: $resolvedTargetPath" -IsSuccess
        }
        Write-ToConsoleLog "Config folder: $configFolderPath"

        # Offer to configure inputs interactively (default is Yes)
        $configureNowResponse = Read-MenuSelection `
            -Title "Would you like to configure the input values interactively now?" `
            -DefaultValue "yes" `
            -Type "boolean" `
            -AllowManualEntry `
            -ManualEntryPrompt "Enter '[y]es' for interactive mode or '[n]o' to update the file manually later"

        if ($configureNowResponse) {
            Request-ALZConfigurationValue `
                -ConfigFolderPath $configFolderPath `
                -IacType $selectedIacType `
                -VersionControl $selectedVersionControl `
                -AzureContextOutputDirectory $outputFolderPath `
                -AzureContextClearCache:$ClearCache.IsPresent
        } else {
            Write-ToConsoleLog "Checking for sensitive inputs that need to be provided..." -IsWarning

            Request-ALZConfigurationValue `
                -ConfigFolderPath $configFolderPath `
                -IacType $selectedIacType `
                -VersionControl $selectedVersionControl `
                -AzureContextOutputDirectory $outputFolderPath `
                -AzureContextClearCache:$ClearCache.IsPresent `
                -SensitiveOnly
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
            $openInVsCodeResponse = Read-MenuSelection `
                -Title "Would you like to open the config folder in $($vsCodeName)?" `
                -DefaultValue "yes" `
                -Type "boolean" `
                -AllowManualEntry `
                -ManualEntryPrompt "Enter '[y]es' to open or '[n]o' to continue without opening"

            if ($openInVsCodeResponse) {
                Write-ToConsoleLog "Opening config folder in $vsCodeName..." -IsSuccess
                & $vsCodeCommand $configFolderPath
            }
        }

        Write-ToConsoleLog "Please check and update the configuration files in the config folder before continuing:" -IsWarning
        Write-ToConsoleLog "  - inputs.yaml: Bootstrap configuration (required)" -IsSelection

        if ($selectedIacType -eq "terraform") {
            Write-ToConsoleLog "  - platform-landing-zone.tfvars: Platform configuration (required)" -IsSelection
            Write-ToConsoleLog "    - starter_locations: Enter the regions for you platform landing zone (required)" -IsSelection
            Write-ToConsoleLog "    - defender_email_security_contact: Enter the email security contact for Microsoft Defender for Cloud (required)" -IsSelection
            Write-ToConsoleLog "  - lib/: Library customizations (optional)" -IsSelection
        } elseif ($selectedIacType -eq "bicep") {
            Write-ToConsoleLog "  - platform-landing-zone.yaml: Platform configuration (required)" -IsSelection
            Write-ToConsoleLog "    - starter_locations: Enter the regions for you platform landing zone (required)" -IsSelection
        }

        Write-ToConsoleLog "For more details, see: https://azure.github.io/Azure-Landing-Zones/accelerator/configuration-files/"

        # Prompt to continue or exit
        $continueResponse = Read-MenuSelection `
            -Title "Have you checked and updated the configuration files? Ready to continue with deployment?" `
            -DefaultValue "yes" `
            -Type "boolean" `
            -AllowManualEntry `
            -ManualEntryPrompt "Enter '[y]es' to continue or '[n]o' to exit"

        if (!$continueResponse) {
            Write-ToConsoleLog "To continue later, run Deploy-Accelerator with the following parameters:" -IsSuccess

            if ($selectedIacType -eq "terraform") {
                Write-ToConsoleLog @"
Deploy-Accelerator ``
    -inputs "$configFolderPath/inputs.yaml", "$configFolderPath/platform-landing-zone.tfvars" ``
    -starterAdditionalFiles "$configFolderPath/lib" ``
    -output "$outputFolderPath"
"@ -Color Cyan
            } elseif ($selectedIacType -eq "bicep") {
                Write-ToConsoleLog @"
Deploy-Accelerator ``
    -inputs "$configFolderPath/inputs.yaml", "$configFolderPath/platform-landing-zone.yaml" ``
    -output "$outputFolderPath"
"@ -Color Cyan
            } else {
                Write-ToConsoleLog @"
Deploy-Accelerator ``
    -inputs "$configFolderPath/inputs.yaml" ``
    -output "$outputFolderPath"
"@ -Color Cyan
            }

            return ConvertTo-AcceleratorResult -Continue $false
        }

        # Build the result for continuing with deployment
        $configPaths = Get-AcceleratorConfigPath -IacType $selectedIacType -ConfigFolderPath $configFolderPath

        Write-ToConsoleLog "Continuing with deployment..." -IsSuccess

        return ConvertTo-AcceleratorResult -Continue $true `
            -InputConfigFilePaths $configPaths.InputConfigFilePaths `
            -StarterAdditionalFiles $configPaths.StarterAdditionalFiles `
            -OutputFolderPath $outputFolderPath
    }
}
