function Request-AcceleratorConfigurationInput {
    <#
    .SYNOPSIS
    Prompts the user for accelerator configuration input and creates the folder structure.
    .DESCRIPTION
    This function interactively prompts the user for the inputs needed to set up the accelerator folder structure,
    calls New-AcceleratorFolderStructure to create the folders and configuration files, and returns the paths
    needed for Deploy-Accelerator to continue.
    .OUTPUTS
    Returns a hashtable with the following keys:
    - Continue: Boolean indicating whether to continue with deployment
    - InputConfigFilePaths: Array of input configuration file paths
    - StarterAdditionalFiles: Array of additional files/folders for the starter module
    - OutputFolderPath: Path to the output folder
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if ($PSCmdlet.ShouldProcess("Accelerator folder structure setup", "prompt and create")) {
        Write-InformationColored "No input configuration files provided. Let's set up the accelerator folder structure first..." -ForegroundColor Green -NewLineBefore -InformationAction Continue
        Write-InformationColored "For more information, see: https://aka.ms/alz/acc/phase2" -ForegroundColor Cyan -InformationAction Continue

        # Prompt for IaC type
        $iacTypeOptions = @("terraform", "bicep", "bicep-classic")
        Write-InformationColored "`nSelect the Infrastructure as Code (IaC) type:" -ForegroundColor Yellow -InformationAction Continue
        for ($i = 0; $i -lt $iacTypeOptions.Count; $i++) {
            $default = if ($i -eq 0) { " (Default)" } else { "" }
            $recommended = if ($iacTypeOptions[$i] -eq "terraform" -or $iacTypeOptions[$i] -eq "bicep") { " (Recommended)" } else { " (Not Recommended)" }
            Write-InformationColored "  [$($i + 1)] $($iacTypeOptions[$i])$default$recommended" -ForegroundColor White -InformationAction Continue
        }
        do {
            $iacTypeSelection = Read-Host "Enter selection (1-$($iacTypeOptions.Count), default: 1)"
            if ([string]::IsNullOrWhiteSpace($iacTypeSelection)) {
                $iacTypeIndex = 0
            } else {
                $iacTypeIndex = [int]$iacTypeSelection - 1
            }
        } while ($iacTypeIndex -lt 0 -or $iacTypeIndex -ge $iacTypeOptions.Count)
        $selectedIacType = $iacTypeOptions[$iacTypeIndex]

        # Prompt for version control
        $versionControlOptions = @("github", "azure-devops", "local")
        Write-InformationColored "`nSelect the Version Control System:" -ForegroundColor Yellow -InformationAction Continue
        for ($i = 0; $i -lt $versionControlOptions.Count; $i++) {
            $default = if ($i -eq 0) { " (Default)" } else { "" }
            Write-InformationColored "  [$($i + 1)] $($versionControlOptions[$i])$default" -ForegroundColor White -InformationAction Continue
        }
        do {
            $vcsSelection = Read-Host "Enter selection (1-$($versionControlOptions.Count), default: 1)"
            if ([string]::IsNullOrWhiteSpace($vcsSelection)) {
                $vcsIndex = 0
            } else {
                $vcsIndex = [int]$vcsSelection - 1
            }
        } while ($vcsIndex -lt 0 -or $vcsIndex -ge $versionControlOptions.Count)
        $selectedVersionControl = $versionControlOptions[$vcsIndex]

        # Prompt for scenario number (Terraform only)
        $selectedScenarioNumber = 1
        if ($selectedIacType -eq "terraform") {
            Write-InformationColored "`nSelect the Terraform scenario (see https://aka.ms/alz/acc/scenarios):" -ForegroundColor Yellow -InformationAction Continue
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
            for ($i = 0; $i -lt $scenarioDescriptions.Count; $i++) {
                $default = if ($i -eq 0) { " (Default)" } else { "" }
                Write-InformationColored "  [$($i + 1)] $($scenarioDescriptions[$i])$default" -ForegroundColor White -InformationAction Continue
            }
            do {
                $scenarioSelection = Read-Host "Enter selection (1-$($scenarioDescriptions.Count), default: 1)"
                if ([string]::IsNullOrWhiteSpace($scenarioSelection)) {
                    $scenarioIndex = 1
                } else {
                    $scenarioIndex = [int]$scenarioSelection
                }
            } while ($scenarioIndex -lt 1 -or $scenarioIndex -gt $scenarioDescriptions.Count)
            $selectedScenarioNumber = $scenarioIndex
        }

        # Prompt for target folder path
        Write-InformationColored "`nEnter the target folder path for the accelerator files (default: ~/accelerator):" -ForegroundColor Yellow -InformationAction Continue
        $targetFolderPathInput = Read-Host "Target folder path"
        if ([string]::IsNullOrWhiteSpace($targetFolderPathInput)) {
            $targetFolderPathInput = "~/accelerator"
        }

        # Run New-AcceleratorFolderStructure
        Write-InformationColored "`nCreating accelerator folder structure..." -ForegroundColor Green -InformationAction Continue

        # Check if folder exists and prompt for force
        $normalizedTargetPath = $targetFolderPathInput
        if ($normalizedTargetPath.StartsWith("~/")) {
            $normalizedTargetPath = Join-Path $HOME $normalizedTargetPath.Replace("~/", "")
        }

        $forceFlag = $false
        $useExistingFolder = $false
        if (Test-Path -Path $normalizedTargetPath) {
            Write-InformationColored "Target folder '$normalizedTargetPath' already exists." -ForegroundColor Yellow -InformationAction Continue
            $forceResponse = Read-Host "Do you want to recreate it? (y/N)"
            if ($forceResponse -eq "y" -or $forceResponse -eq "Y") {
                $forceFlag = $true
            } else {
                # User wants to keep existing folder - validate config files exist
                $useExistingFolder = $true
                Write-InformationColored "`nValidating existing folder structure..." -ForegroundColor Cyan -InformationAction Continue

                $configFolderPath = Join-Path $normalizedTargetPath "config"
                if (-not (Test-Path -Path $configFolderPath)) {
                    Write-InformationColored "ERROR: Config folder not found at '$configFolderPath'" -ForegroundColor Red -InformationAction Continue
                    Write-InformationColored "Please create the folder structure first by choosing 'y' to recreate, or run New-AcceleratorFolderStructure manually." -ForegroundColor Yellow -InformationAction Continue
                    return @{
                        Continue               = $false
                        InputConfigFilePaths   = @()
                        StarterAdditionalFiles = @()
                        OutputFolderPath       = ""
                    }
                }

                # Check for inputs.yaml (required for all types)
                $inputsYamlPath = Join-Path $configFolderPath "inputs.yaml"
                if (-not (Test-Path -Path $inputsYamlPath)) {
                    Write-InformationColored "ERROR: Required configuration file not found: inputs.yaml" -ForegroundColor Red -InformationAction Continue
                    Write-InformationColored "Please create the folder structure first by choosing 'y' to recreate, or run New-AcceleratorFolderStructure manually." -ForegroundColor Yellow -InformationAction Continue
                    return @{
                        Continue               = $false
                        InputConfigFilePaths   = @()
                        StarterAdditionalFiles = @()
                        OutputFolderPath       = ""
                    }
                }

                # Validate that inputs.yaml is valid YAML
                $inputsContent = Get-Content -Path $inputsYamlPath -Raw
                try {
                    $null = $inputsContent | ConvertFrom-Yaml
                } catch {
                    Write-InformationColored "ERROR: inputs.yaml is not valid YAML." -ForegroundColor Red -InformationAction Continue
                    Write-InformationColored "Parse error: $($_.Exception.Message)" -ForegroundColor Red -InformationAction Continue
                    Write-InformationColored "Please fix the YAML syntax in '$inputsYamlPath' and try again." -ForegroundColor Yellow -InformationAction Continue
                    return @{
                        Continue               = $false
                        InputConfigFilePaths   = @()
                        StarterAdditionalFiles = @()
                        OutputFolderPath       = ""
                    }
                }

                # Try to detect the IaC type from existing files
                $tfvarsPath = Join-Path $configFolderPath "platform-landing-zone.tfvars"
                $bicepYamlPath = Join-Path $configFolderPath "platform-landing-zone.yaml"

                if (Test-Path -Path $tfvarsPath) {
                    $selectedIacType = "terraform"
                    Write-InformationColored "  Detected IaC type: terraform (found platform-landing-zone.tfvars)" -ForegroundColor Green -InformationAction Continue
                } elseif (Test-Path -Path $bicepYamlPath) {
                    $selectedIacType = "bicep"
                    Write-InformationColored "  Detected IaC type: bicep (found platform-landing-zone.yaml)" -ForegroundColor Green -InformationAction Continue
                } else {
                    $selectedIacType = "bicep-classic"
                    Write-InformationColored "  Detected IaC type: bicep-classic (no platform config file found)" -ForegroundColor Green -InformationAction Continue
                }

                # Detect version control from inputs.yaml content (already loaded above)
                if ($inputsContent -match "github_personal_access_token|github_organization_name") {
                    $selectedVersionControl = "github"
                } elseif ($inputsContent -match "azure_devops_personal_access_token|azure_devops_organization_name") {
                    $selectedVersionControl = "azure-devops"
                } else {
                    $selectedVersionControl = "local"
                }
                Write-InformationColored "  Detected version control: $selectedVersionControl" -ForegroundColor Green -InformationAction Continue

                Write-InformationColored "  Found inputs.yaml (valid YAML)" -ForegroundColor Green -InformationAction Continue
            }
        }

        if ((-not (Test-Path -Path $normalizedTargetPath) -or $forceFlag) -and -not $useExistingFolder) {
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

        # Build the input config paths based on the IaC type (only set if not already set from validation)
        if (-not $useExistingFolder) {
            $configFolderPath = Join-Path $resolvedTargetPath "config"
        }

        if ($useExistingFolder) {
            Write-InformationColored "`nUsing existing folder structure at: $resolvedTargetPath" -ForegroundColor Green -InformationAction Continue
        }
        Write-InformationColored "Config folder: $configFolderPath" -ForegroundColor Cyan -InformationAction Continue

        # Offer to configure inputs interactively (default is Yes)
        $configureNowResponse = Read-Host "`nWould you like to configure the input values interactively now? (Y/n)"
        if ($configureNowResponse -ne "n" -and $configureNowResponse -ne "N") {
            # Query Azure for management groups and subscriptions (for interactive selection)
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

        Write-InformationColored "`nPlease update the configuration files in the config folder before continuing:" -ForegroundColor Yellow -InformationAction Continue
        Write-InformationColored "  - inputs.yaml: Bootstrap configuration (required)" -ForegroundColor White -InformationAction Continue

        if ($selectedIacType -eq "terraform") {
            Write-InformationColored "  - platform-landing-zone.tfvars: Platform configuration (required)" -ForegroundColor White -InformationAction Continue
            Write-InformationColored "  - lib/: Library customizations (optional)" -ForegroundColor White -InformationAction Continue
        } elseif ($selectedIacType -eq "bicep") {
            Write-InformationColored "  - platform-landing-zone.yaml: Platform configuration (required)" -ForegroundColor White -InformationAction Continue
        }

        Write-InformationColored "`nFor more details, see: https://azure.github.io/Azure-Landing-Zones/accelerator/configuration-files/" -ForegroundColor Cyan -InformationAction Continue

        # Prompt to continue or exit
        $continueResponse = Read-Host "`nHave you updated the configuration files? Enter 'yes' to continue with deployment, or 'no' to exit and configure later"
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

            return @{
                Continue               = $false
                InputConfigFilePaths   = @()
                StarterAdditionalFiles = @()
                OutputFolderPath       = ""
            }
        }

        # Build the result for continuing with deployment
        $inputConfigFilePaths = @()
        $starterAdditionalFiles = @()

        if ($selectedIacType -eq "terraform") {
            $inputConfigFilePaths = @(
                "$configFolderPath/inputs.yaml",
                "$configFolderPath/platform-landing-zone.tfvars"
            )
            $libFolderPath = "$configFolderPath/lib"
            if (Test-Path $libFolderPath) {
                $starterAdditionalFiles = @($libFolderPath)
            }
        } elseif ($selectedIacType -eq "bicep") {
            $inputConfigFilePaths = @(
                "$configFolderPath/inputs.yaml",
                "$configFolderPath/platform-landing-zone.yaml"
            )
        } else {
            # bicep-classic
            $inputConfigFilePaths = @(
                "$configFolderPath/inputs.yaml"
            )
        }

        Write-InformationColored "`nContinuing with deployment..." -ForegroundColor Green -InformationAction Continue

        return @{
            Continue               = $true
            InputConfigFilePaths   = $inputConfigFilePaths
            StarterAdditionalFiles = $starterAdditionalFiles
            OutputFolderPath       = "$resolvedTargetPath/output"
        }
    }
}
