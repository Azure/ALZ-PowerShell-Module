function Deploy-Accelerator {
    <#
    .SYNOPSIS
    Deploys an accelerator according to the supplied inputs.
    .DESCRIPTION
    This function is used to deploy accelerators consisting or bootstrap and optionally starter modules. The accelerators are designed to simplify and speed up configuration of common Microsoft patterns, such as CI / CD for Azure Landing Zones.
    .EXAMPLE
    Deploy-Accelerator
    .EXAMPLE
    Deploy-Accelerator -c "./config.yaml" -o "."
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = "[REQUIRED] The configuration inputs in json, yaml or tfvars format. Environment variable: ALZ_input_config_path"
        )]
        [Alias("inputs")]
        [Alias("c")]
        [Alias("inputConfigFilePath")]
        [string[]] $inputConfigFilePaths = @(),

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The additional files or folders to be copied directly to the starter module root folder. Environment variable: ALZ_starter_additional_files. Config file input: starter_additional_files."
        )]
        [Alias("saf")]
        [Alias("starterAdditionalFiles")]
        [string[]] $starter_additional_files = @(),

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The target directory for the accelerator working set of files. Defaults to current working folder. Environment variable: ALZ_output_folder_path. Config file input: output_folder_path."
        )]
        [Alias("output")]
        [Alias("o")]
        [Alias("targetDirectory")]
        [string] $output_folder_path = ".",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The name of the output folder within the target directory. Defaults to 'output'. Environment variable: ALZ_output_folder_name. Config file input: output_folder_name."
        )]
        [Alias("ofn")]
        [string] $output_folder_name = "output",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The version tag of the bootstrap module release to download. Defaults to latest. Environment variable: ALZ_bootstrap_module_version. Config file input: bootstrap_module_version."
        )]
        [Alias("bv")]
        [Alias("bootstrapRelease")]
        [string] $bootstrap_module_version = "latest",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The version tag of the starter module release to download. Defaults to latest. Environment variable: ALZ_starter_module_version. Config file input: starter_module_version."
        )]
        [Alias("sv")]
        [Alias("starterRelease")]
        [string] $starter_module_version = "latest",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Determines whether to deploy the bootstrap without prompting for approval. This is used for automation. Environment variable: ALZ_auto_approve. Config file input: auto_approve."
        )]
        [Alias("aa")]
        [Alias("autoApprove")]
        [switch] $auto_approve,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Determines that this run is to destroy the bootstrap. This is used to cleanup experiments. Environment variable: ALZ_destroy. Config file input: destroy."
        )]
        [Alias("d")]
        [switch] $destroy,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The bootstrap modules repository url. This can be overridden for custom modules. Environment variable: ALZ_bootstrap_module_url. Config file input: bootstrap_module_url."
        )]
        [Alias("bu")]
        [Alias("bootstrapModuleUrl")]
        [string] $bootstrap_module_url = "https://github.com/Azure/accelerator-bootstrap-modules",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The bootstrap modules release artifact name. This can be overridden for custom modules. Environment variable: ALZ_bootstrap_module_release_artifact_name. Config file input: bootstrap_module_release_artifact_name."
        )]
        [Alias("ba")]
        [Alias("bootstrapModuleReleaseArtifactName")]
        [string] $bootstrap_module_release_artifact_name = "bootstrap_modules.zip",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The bootstrap config file path within the bootstrap module. This can be overridden for custom modules. Environment variable: ALZ_bootstrap_config_path. Config file input: bootstrap_config_path."
        )]
        [Alias("bc")]
        [Alias("bootstrapConfigPath")]
        [string] $bootstrap_config_path = ".config/ALZ-Powershell.config.json",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The folder that contains the bootstrap modules in the bootstrap repo. This can be overridden for custom modules. Environment variable: ALZ_bootstrap_source_folder. Config file input: bootstrap_source_folder."
        )]
        [Alias("bf")]
        [Alias("bootstrapSourceFolder")]
        [string] $bootstrap_source_folder = ".",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Used to override the bootstrap folder source. This can be used to provide a folder locally in restricted environments or dev. Environment variable: ALZ_bootstrapModuleOverrideFolderPath. Config file input: bootstrap_module_override_folder_path."
        )]
        [Alias("bo")]
        [Alias("bootstrapModuleOverrideFolderPath")]
        [string] $bootstrap_module_override_folder_path = "",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Used to override the starter folder source. This can be used to provide a folder locally in restricted environments. Environment variable: ALZ_starterModuleOverrideFolderPath. Config file input: starter_module_override_folder_path."
        )]
        [Alias("so")]
        [Alias("starterModuleOverrideFolderPath")]
        [string] $starter_module_override_folder_path = "",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Whether to skip checks that involve internet connection. The can allow running in restricted environments. Environment variable: ALZ_skip_internet_checks. Config file input: skip_internet_checks."
        )]
        [Alias("si")]
        [Alias("skipInternetChecks")]
        [switch] $skip_internet_checks,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Whether to overwrite bootstrap and starter modules if they already exist. Warning, this may result in unexpected behavior and should only be used for local development purposes. Environment variable: ALZ_replace_files. Config file input: replace_files."
        )]
        [Alias("rf")]
        [Alias("replaceFiles")]
        [switch] $replace_files,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] An extra level of logging that is turned off by default for easier debugging. Environment variable: ALZ_write_verbose_logs. Config file input: write_verbose_logs."
        )]
        [Alias("v")]
        [Alias("writeVerboseLogs")]
        [switch] $write_verbose_logs,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Determines whether to convert tfvars input files to tfvars.json files. Environment variable: ALZ_convert_tfvars_to_json. Config file input: convert_tfvars_to_json."
        )]
        [Alias("tj")]
        [Alias("convertTfvarsToJson")]
        [switch] $convert_tfvars_to_json,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Determines whether to skip the requirements check. This is not recommended."
        )]
        [Alias("skipRequirementsCheck")]
        [switch] $skip_requirements_check,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Determines whether to skip the requirements check for the ALZ PowerShell Module version only. This is not recommended."
        )]
        [Alias("skipAlzModuleVersionRequirementsCheck")]
        [switch] $skip_alz_module_version_requirements_check,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Determines whether to skip attempting to install the powershell-yaml module if it is not installed."
        )]
        [Alias("skipYamlModuleInstall")]
        [switch] $skip_yaml_module_install,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Determines whether Clean the bootstrap folder of Terraform meta files. Only use for development purposes."
        )]
        [switch] $cleanBootstrapFolder,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Determines whether to upgrade to the latest version of modules when version is set to 'latest'. Without this flag, existing versions are used. Environment variable: ALZ_upgrade. Config file input: upgrade."
        )]
        [Alias("u")]
        [switch] $upgrade,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Clears the cached Azure context (management groups, subscriptions, regions) and fetches fresh data from Azure."
        )]
        [Alias("cc")]
        [switch] $clear_cache
    )

    $ProgressPreference = "SilentlyContinue"

    # Check if we need to prompt for folder structure creation (which creates YAML files)
    $needsFolderStructureSetup = $false
    $envInputConfigPaths = $env:ALZ_input_config_path

    if ($inputConfigFilePaths.Length -eq 0 -and ($null -eq $envInputConfigPaths -or $envInputConfigPaths -eq "")) {
        $needsFolderStructureSetup = $true
    }

    # Determine if YAML module check is needed
    $checkYamlModule = $needsFolderStructureSetup  # Always need YAML if prompting for folder structure
    if (-not $checkYamlModule) {
        # Check if any supplied input files are YAML
        $pathsToCheck = if ($inputConfigFilePaths.Length -gt 0) {
            $inputConfigFilePaths
        } else {
            $envInputConfigPaths -split "," | Where-Object { $_ -and $_.Trim() }
        }
        foreach ($path in $pathsToCheck) {
            if ($null -ne $path -and $path.Trim() -ne "") {
                try {
                    $extension = [System.IO.Path]::GetExtension($path).ToLower()
                    if ($extension -eq ".yml" -or $extension -eq ".yaml") {
                        $checkYamlModule = $true
                        break
                    }
                } catch {
                    continue
                }
            }
        }
    }

    # Check software requirements first before any prompting
    $toolingResult = $null
    if ($skip_requirements_check.IsPresent) {
        Write-InformationColored "WARNING: Skipping the software requirements check..." -ForegroundColor Yellow -InformationAction Continue
    } else {
        Write-InformationColored "Checking the software requirements for the Accelerator..." -ForegroundColor Green -InformationAction Continue
        $toolingResult = Test-Tooling -skipAlzModuleVersionCheck:$skip_alz_module_version_requirements_check.IsPresent -checkYamlModule:$checkYamlModule -skipYamlModuleInstall:$skip_yaml_module_install.IsPresent -skipAzureLoginCheck:$needsFolderStructureSetup -destroy:$destroy.IsPresent
    }

    # If az cli is installed but not logged in, prompt for tenant ID and login with device code
    if ($needsFolderStructureSetup -and $toolingResult -and $toolingResult.AzCliInstalledButNotLoggedIn) {
        Write-InformationColored "`nAzure CLI is installed but not logged in. Let's log you in..." -ForegroundColor Yellow -InformationAction Continue
        Write-InformationColored "You'll need your Azure Tenant ID. You can find this in the Azure Portal under Microsoft Entra ID > Overview." -ForegroundColor Cyan -InformationAction Continue

        $tenantId = ""
        $guidRegex = "^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$"
        do {
            $tenantId = Read-Host "`nEnter your Azure Tenant ID (GUID)"
            if ($tenantId -notmatch $guidRegex) {
                Write-InformationColored "Invalid Tenant ID format. Please enter a valid GUID (e.g., 00000000-0000-0000-0000-000000000000)" -ForegroundColor Red -InformationAction Continue
            }
        } while ($tenantId -notmatch $guidRegex)

        Write-InformationColored "`nLogging in to Azure using device code authentication..." -ForegroundColor Green -InformationAction Continue
        Write-InformationColored "Opening browser to https://microsoft.com/devicelogin for you to authenticate..." -ForegroundColor Cyan -InformationAction Continue

        try {
            Start-Process "https://microsoft.com/devicelogin"
        } catch {
            Write-InformationColored "Could not open browser automatically. Please navigate to https://microsoft.com/devicelogin manually." -ForegroundColor Yellow -InformationAction Continue
        }
        az login --allow-no-subscriptions --use-device-code --tenant $tenantId
        if ($LASTEXITCODE -ne 0) {
            Write-InformationColored "Azure login failed. Please try again or login manually using 'az login --tenant $tenantId'." -ForegroundColor Red -InformationAction Continue
            throw "Azure login failed."
        }

        Write-InformationColored "Successfully logged in to Azure!" -ForegroundColor Green -InformationAction Continue
    }

    # If no inputs provided, prompt user for folder structure setup
    if ($needsFolderStructureSetup) {
        $setupResult = Request-AcceleratorConfigurationInput -Destroy:$destroy.IsPresent -ClearCache:$clear_cache.IsPresent -OutputFolderName $output_folder_name

        if (-not $setupResult.Continue) {
            return
        }

        # Set the parameters from the setup result
        $inputConfigFilePaths = $setupResult.InputConfigFilePaths
        if ($setupResult.StarterAdditionalFiles.Count -gt 0) {
            $starter_additional_files = $setupResult.StarterAdditionalFiles
        }
        $output_folder_path = $setupResult.OutputFolderPath
    }

    Write-InformationColored "Getting ready to deploy the accelerator with you..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

    if ($PSCmdlet.ShouldProcess("Accelerator setup", "modify")) {

        # Normalize output folder path
        Write-Verbose "Normalizing: $output_folder_path"
        if($output_folder_path.StartsWith("~/" )) {
            $output_folder_path = Join-Path $HOME $output_folder_path.Replace("~/", "")
        }
        Write-Verbose "Using output folder path: $output_folder_path"

        # Check and install tools needed
        $toolsPath = Join-Path -Path $output_folder_path -ChildPath ".tools"
        if ($skipInternetChecks) {
            Write-InformationColored "Skipping Terraform tool check as you used the skipInternetCheck parameter. Please ensure you have the most recent version of Terraform installed" -ForegroundColor Yellow -InformationAction Continue
        } else {
            Write-InformationColored "Checking you have the latest version of Terraform installed..." -ForegroundColor Green -NewLineBefore -InformationAction Continue
            Get-TerraformTool -version "latest" -toolsPath $toolsPath
            $hclParserToolPath = Get-HCLParserTool -toolVersion "v0.6.0" -toolsPath $toolsPath
        }

        # Get User Inputs from the input config file
        $inputConfig = $null
        if ($inputConfigFilePaths.Length -eq 0) {
            $envInputConfigPaths = $env:ALZ_input_config_path
            if ($null -ne $envInputConfigPaths -and $envInputConfigPaths -ne "") {
                $inputConfigFilePaths = $envInputConfigPaths -split ","
            } else {
                Write-InformationColored "No input configuration file path has been provided. Please provide the path(s) to your configuration file(s)..." -ForegroundColor Red -InformationAction Continue
                throw "No input configuration file path has been provided. Please provide the path(s) to your configuration file(s)..."
            }
        }

        # Get the input config from yaml and json files
        foreach ($inputConfigFilePath in $inputConfigFilePaths) {
            if($inputConfigFilePath.StartsWith("~/" )) {
                $inputConfigFilePath = Join-Path $HOME $inputConfigFilePath.Replace("~/", "")
            }
            Write-Verbose "Loading input config from file: $inputConfigFilePath"
            $inputConfig = Get-ALZConfig -configFilePath $inputConfigFilePath -inputConfig $inputConfig -hclParserToolPath $hclParserToolPath
        }

        # Set accelerator input config from input file, environment variables or parameters
        $parameters = (Get-Command -Name $MyInvocation.InvocationName).Parameters
        $parametersWithValues = @{}
        foreach ($parameterKey in $parameters.Keys) {
            $parameter = $parameters[$parameterKey]
            if ($parameter.IsDynamic) {
                continue
            }

            $parameterValue = Get-Variable -Name $parameterKey -ValueOnly -ErrorAction SilentlyContinue

            if ($null -ne $parameterValue) {
                $parametersWithValues[$parameterKey] = @{
                    type    = $parameters[$parameterKey].ParameterType.Name
                    value   = $parameterValue
                    aliases = $parameter.Aliases
                }
            }
        }
        $inputConfig = Convert-ParametersToInputConfig -inputConfig $inputConfig -parameters $parametersWithValues

        Write-Verbose "Initial Input config: $(ConvertTo-Json $inputConfig -Depth 100)"

        # Throw if IAC type is not specified
        if (!$inputConfig.iac_type.Value) {
            Write-InformationColored "No Infrastructure as Code type has been specified. Please supply the IAC type you wish to deploy..." -ForegroundColor Red -InformationAction Continue
            throw "No Infrastructure as Code type has been specified. Please supply the IAC type you wish to deploy..."
        }

        if ($inputConfig.iac_type.Value.ToString() -like "bicep*") {
            Write-InformationColored "Although you have selected Bicep, the Accelerator leverages the Terraform tool to bootstrap your Version Control System and Azure. This will not impact your choice of Bicep post this initial bootstrap. Please refer to our documentation for further details..." -ForegroundColor Yellow -InformationAction Continue
        }

        # Download the bootstrap modules
        $bootstrapReleaseTag = ""
        $bootstrapPath = ""
        $bootstrapTargetFolder = "bootstrap"

        Write-InformationColored "Checking and Downloading the bootstrap module..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

        if($inputConfig.bootstrap_module_override_folder_path.Value.StartsWith("~/" )) {
            $inputConfig.bootstrap_module_override_folder_path.Value = Join-Path $HOME $inputConfig.bootstrap_module_override_folder_path.Value.Replace("~/", "")
        }

        $versionAndPath = New-ModuleSetup `
            -targetDirectory $inputConfig.output_folder_path.Value `
            -targetFolder $bootstrapTargetFolder `
            -sourceFolder $inputConfig.bootstrap_source_folder.Value `
            -url $inputConfig.bootstrap_module_url.Value `
            -release $inputConfig.bootstrap_module_version.Value `
            -releaseArtifactName $inputConfig.bootstrap_module_release_artifact_name.Value `
            -moduleOverrideFolderPath $inputConfig.bootstrap_module_override_folder_path.Value `
            -skipInternetChecks $inputConfig.skip_internet_checks.Value `
            -replaceFile:$inputConfig.replace_files.Value `
            -upgrade:$inputConfig.upgrade.Value `
            -autoApprove:$inputConfig.auto_approve.Value

        $bootstrapReleaseTag = $versionAndPath.releaseTag
        $bootstrapPath = $versionAndPath.path

        # Configure the starter module path
        $starterFolder = "starter"
        $starterModuleTargetFolder = $starterFolder

        # Setup the variables for bootstrap and starter modules
        $hasStarterModule = $false
        $starterModuleUrl = ""
        $starterModuleSourceFolder = "."
        $starterReleaseArtifactName = ""
        $starterConfigFilePath = ""

        $bootstrapDetails = $null

        # Request the bootstrap type if not already specified
        if(!$inputConfig.bootstrap_module_name.Value) {
            Write-InformationColored "No bootstrap module has been specified. Please supply the bootstrap module you wish to deploy..." -ForegroundColor Red -InformationAction Continue
            throw "No bootstrap module has been specified. Please supply the bootstrap module you wish to deploy..."
        }

        $bootstrap_module_name = $inputConfig.bootstrap_module_name.Value.Trim()

        $bootstrapAndStarterConfig = Get-BootstrapAndStarterConfig `
            -iac $inputConfig.iac_type.Value `
            -bootstrap $bootstrap_module_name `
            -bootstrapPath $bootstrapPath `
            -bootstrapConfigPath $inputConfig.bootstrap_config_path.Value `
            -toolsPath $toolsPath

        $bootstrapDetails = $bootstrapAndStarterConfig.bootstrapDetails
        $hasStarterModule = $bootstrapAndStarterConfig.hasStarterModule
        $starterModuleUrl = $bootstrapAndStarterConfig.starterModuleUrl
        $starterModuleSourceFolder = $bootstrapAndStarterConfig.starterModuleSourceFolder
        $starterReleaseArtifactName = $bootstrapAndStarterConfig.starterReleaseArtifactName
        $starterConfigFilePath = $bootstrapAndStarterConfig.starterConfigFilePath

        # Download the starter modules
        $starterReleaseTag = ""
        $starterConfig = $null

        if ($hasStarterModule) {
            Write-InformationColored "Checking and downloading the starter module..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

            if($inputConfig.starter_module_override_folder_path.Value.StartsWith("~/" )) {
                $inputConfig.starter_module_override_folder_path.Value = Join-Path $HOME $inputConfig.starter_module_override_folder_path.Value.Replace("~/", "")
            }

            $versionAndPath = New-ModuleSetup `
                -targetDirectory $inputConfig.output_folder_path.Value `
                -targetFolder $starterModuleTargetFolder `
                -sourceFolder $starterModuleSourceFolder `
                -url $starterModuleUrl `
                -release $inputConfig.starter_module_version.Value `
                -releaseArtifactName $starterReleaseArtifactName `
                -moduleOverrideFolderPath $inputConfig.starter_module_override_folder_path.Value `
                -skipInternetChecks $inputConfig.skip_internet_checks.Value `
                -replaceFile:$inputConfig.replace_files.Value `
                -upgrade:$inputConfig.upgrade.Value `
                -autoApprove:$inputConfig.auto_approve.Value

            $starterReleaseTag = $versionAndPath.releaseTag
            $starterPath = $versionAndPath.path
            $starterConfig = Get-StarterConfig -starterPath $starterPath -starterConfigPath $starterConfigFilePath
        }

        # Set computed interface inputs
        $inputConfig | Add-Member -MemberType NoteProperty -Name "bicep_config_file_path" -Value @{
            Value     = $starterConfigFilePath
            Source    = "calculated"
            Sensitive = $false
        }
        $inputConfig | Add-Member -MemberType NoteProperty -Name "on_demand_folder_repository" -Value @{
            Value     = $starterModuleUrl
            Source    = "calculated"
            Sensitive = $false
        }
        $inputConfig | Add-Member -MemberType NoteProperty -Name "on_demand_folder_artifact_name" -Value @{
            Value     = $starterReleaseArtifactName
            Source    = "calculated"
            Sensitive = $false
        }
        $inputConfig | Add-Member -MemberType NoteProperty -Name "release_version" -Value @{
            Value     = ($starterReleaseTag -eq "local" ? $inputConfig.starter_module_version.Value : $starterReleaseTag)
            Source    = "calculated"
            Sensitive = $false
        }
        $inputConfig | Add-Member -MemberType NoteProperty -Name "time_stamp" -Value @{
            Value     = (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss")
            Source    = "calculated"
            Sensitive = $false
        }

        # Run the bootstrap
        $bootstrapTargetPath = Join-Path $inputConfig.output_folder_path.Value $bootstrapTargetFolder
        $starterTargetPath = Join-Path $inputConfig.output_folder_path.Value $starterFolder

        # Normalize starter additional files input
        $starterAdditionalFiles = @()
        foreach ($additionalFile in $inputConfig.starter_additional_files.Value) {
            if($additionalFile.StartsWith("~/" )) {
                $additionalFile = Join-Path $HOME $additionalFile.Replace("~/", "")
            }
            $starterAdditionalFiles += $additionalFile
        }
        $inputConfig.starter_additional_files.Value = $starterAdditionalFiles

        New-Bootstrap `
            -iac $inputConfig.iac_type.Value `
            -bootstrapDetails $bootstrapDetails `
            -inputConfig $inputConfig `
            -bootstrapTargetPath $bootstrapTargetPath `
            -bootstrapRelease $bootstrapReleaseTag `
            -hasStarter:$hasStarterModule `
            -starterTargetPath $starterTargetPath `
            -starterRelease $starterReleaseTag `
            -starterConfig $starterConfig `
            -autoApprove:$inputConfig.auto_approve.Value `
            -destroy:$inputConfig.destroy.Value `
            -writeVerboseLogs:$inputConfig.write_verbose_logs.Value `
            -hclParserToolPath $hclParserToolPath `
            -convertTfvarsToJson:$inputConfig.convert_tfvars_to_json.Value `
            -inputConfigFilePaths $inputConfigFilePaths `
            -starterAdditionalFiles $inputConfig.starter_additional_files.Value `
            -cleanBootstrapFolder:$cleanBootstrapFolder.IsPresent
    }

    $ProgressPreference = "Continue"

    return
}
