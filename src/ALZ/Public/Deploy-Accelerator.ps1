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
            HelpMessage = "[REQUIRED] The infrastructure as code type to target. Supported options are 'bicep', 'terrform' or 'local'. Environment variable: ALZ_iac_type. Config file input: iac_type.")]
        [Alias("i")]
        [Alias("iac")]
        [string] $iac_type = "",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[REQUIRED] The bootstrap module to deploy. Environment variable: ALZ_bootstrap_module_name. Config file input: bootstrap_module_name."
        )]
        [Alias("b")]
        [Alias("bootstrap")]
        [string] $bootstrap_module_name = "",

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[REQUIRED] The starter module to deploy. Environment variable: ALZ_starter_module_name. Config file input: starter_module_name."
        )]
        [Alias("s")]
        [Alias("starter")]
        [string] $starter_module_name = "",

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
            HelpMessage = "[OPTIONAL] Determines that this run is to destroup the bootstrap. This is used to cleanup experiments. Environment variable: ALZ_destroy. Config file input: destroy."
        )]
        [Alias("d")]
        [switch] $destroy,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] The bootstrap modules reposiotry url. This can be overridden for custom modules. Environment variable: ALZ_bootstrap_module_url. Config file input: bootstrap_module_url."
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
            HelpMessage = "[OPTIONAL] The folder that containes the bootstrap modules in the bootstrap repo. This can be overridden for custom modules. Environment variable: ALZ_bootstrap_source_folder. Config file input: bootstrap_source_folder."
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
            HelpMessage = "[OPTIONAL] Whether to overwrite bootstrap and starter modules if they already exist. Warning, this may result in unexpected behaviour and should only be used for local development purposes. Environment variable: ALZ_replace_files. Config file input: replace_files."
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
        [switch] $skip_alz_module_version_requirements_check
    )

    $ProgressPreference = "SilentlyContinue"

    if($skip_requirements_check.IsPresent) {
        Write-InformationColored "WARNING: Skipping the software requirements check..." -ForegroundColor Yellow -InformationAction Continue
    } else {
        Write-InformationColored "Checking the software requirements for the Accelerator..." -ForegroundColor Green -InformationAction Continue
        Test-Tooling -skipAlzModuleVersionCheck:$skip_alz_module_version_requirements_check.IsPresent
    }

    Write-InformationColored "Getting ready to deploy the accelerator with you..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

    if ($PSCmdlet.ShouldProcess("Accelerator setup", "modify")) {

        # Check and install tools needed
        $toolsPath = Join-Path -Path $output_folder_path -ChildPath ".tools"
        if($skipInternetChecks) {
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
            if($null -ne $envInputConfigPaths -and $envInputConfigPaths -ne "") {
                $inputConfigFilePaths = $envInputConfigPaths -split ","
            } else {
                Write-InformationColored "No input configuration file path has been provided. Please provide the path(s) to your configuration file(s)..." -ForegroundColor Yellow -InformationAction Continue
                $inputConfigFilePaths = @(Request-SpecialInput -type "inputConfigFilePath")
            }
        }

        # Get the input config from yaml and json files
        foreach($inputConfigFilePath in $inputConfigFilePaths) {
            $inputConfig = Get-ALZConfig -configFilePath $inputConfigFilePath -inputConfig $inputConfig -hclParserToolPath $hclParserToolPath
        }

        # Set accelerator input config from input file, environment variables or parameters
        $parameters = (Get-Command -Name $MyInvocation.InvocationName).Parameters
        $parametersWithValues = @{}
        foreach ($parameterKey in $parameters.Keys) {
            $parameter = $parameters[$parameterKey]
            if($parameter.IsDynamic) {
                continue
            }

            $parameterValue = Get-Variable -Name $parameterKey -ValueOnly -ErrorAction SilentlyContinue

            if($null -ne $parameterValue) {
                $parametersWithValues[$parameterKey] = @{
                    type    = $parameters[$parameterKey].ParameterType.Name
                    value   = $parameterValue
                    aliases = $parameter.Aliases
                }
            }
        }
        $inputConfig = Convert-ParametersToInputConfig -inputConfig $inputConfig -parameters $parametersWithValues

        # Get the IAC type if not specified
        if ($inputConfig.iac_type.Value -eq "") {
            $inputConfig.iac_type = @{
                Value  = Request-SpecialInput -type "iac"
                Source = "user"
            }
        }

        if ($inputConfig.iac_type.Value -eq "bicep") {
            Write-InformationColored "Although you have selected Bicep, the Accelerator leverages the Terraform tool to bootstrap your Version Control System and Azure. This is will not impact your choice of Bicep post this initial bootstrap. Please refer to our documentation for further details..." -ForegroundColor Yellow -InformationAction Continue
        }

        Write-Verbose "Initial Input config: $(ConvertTo-Json $inputConfig -Depth 100)"

        # Download the bootstrap modules
        $bootstrapReleaseTag = ""
        $bootstrapPath = ""
        $bootstrapTargetFolder = "bootstrap"

        Write-InformationColored "Checking and Downloading the bootstrap module..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

        $versionAndPath = New-ModuleSetup `
            -targetDirectory $inputConfig.output_folder_path.Value `
            -targetFolder $bootstrapTargetFolder `
            -sourceFolder $inputConfig.bootstrap_source_folder.Value `
            -url $inputConfig.bootstrap_module_url.Value `
            -release $inputConfig.bootstrap_module_version.Value `
            -releaseArtifactName $inputConfig.bootstrap_module_release_artifact_name.Value `
            -moduleOverrideFolderPath $inputConfig.bootstrap_module_override_folder_path.Value `
            -skipInternetChecks $inputConfig.skip_internet_checks.Value `
            -replaceFile:$inputConfig.replace_files.Value

        $bootstrapReleaseTag = $versionAndPath.releaseTag
        $bootstrapPath = $versionAndPath.path

        # Configure the starter module path
        $starterFolder = "starter"
        $starterModuleTargetFolder = $starterFolder

        # Setup the variables for bootstrap and starter modules
        $hasStarterModule = $false
        $starterModuleUrl = $bicepLegacyUrl
        $starterModuleSourceFolder = "."
        $starterReleaseArtifactName = ""
        $starterConfigFilePath = ""

        $bootstrapDetails = $null
        $validationConfig = $null
        $zonesSupport = $null

        # Request the bootstrap type if not already specified
        if($inputConfig.bootstrap_module_name.Value -eq "") {
            $inputConfig.bootstrap_module_name = @{
                Value  = Request-SpecialInput -type "bootstrap" -bootstrapModules $bootstrapModules
                Source = "user"
            }
        }

        $bootstrapAndStarterConfig = Get-BootstrapAndStarterConfig `
            -iac $inputConfig.iac_type.Value `
            -bootstrap $inputConfig.bootstrap_module_name.Value `
            -bootstrapPath $bootstrapPath `
            -bootstrapConfigPath $inputConfig.bootstrap_config_path.Value `
            -toolsPath $toolsPath

        $bootstrapDetails = $bootstrapAndStarterConfig.bootstrapDetails
        $hasStarterModule = $bootstrapAndStarterConfig.hasStarterModule
        $starterModuleUrl = $bootstrapAndStarterConfig.starterModuleUrl
        $starterModuleSourceFolder = $bootstrapAndStarterConfig.starterModuleSourceFolder
        $starterReleaseArtifactName = $bootstrapAndStarterConfig.starterReleaseArtifactName
        $starterConfigFilePath = $bootstrapAndStarterConfig.starterConfigFilePath
        $validationConfig = $bootstrapAndStarterConfig.validationConfig
        $zonesSupport = $bootstrapAndStarterConfig.zonesSupport

        # Download the starter modules
        $starterReleaseTag = ""
        $starterConfig = $null

        if ($hasStarterModule) {
            Write-InformationColored "Checking and downloading the starter module..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

            $versionAndPath = New-ModuleSetup `
                -targetDirectory $inputConfig.output_folder_path.Value `
                -targetFolder $starterModuleTargetFolder `
                -sourceFolder $starterModuleSourceFolder `
                -url $starterModuleUrl `
                -release $inputConfig.starter_module_version.Value `
                -releaseArtifactName $starterReleaseArtifactName `
                -moduleOverrideFolderPath $inputConfig.starter_module_override_folder_path.Value `
                -skipInternetChecks $inputConfig.skip_internet_checks.Value `
                -replaceFile:$inputConfig.replace_files.Value

            $starterReleaseTag = $versionAndPath.releaseTag
            $starterPath = $versionAndPath.path
            $starterConfig = Get-StarterConfig -starterPath $starterPath -starterConfigPath $starterConfigFilePath
        }

        # Set computed interface inputs
        $inputConfig | Add-Member -MemberType NoteProperty -Name "on_demand_folder_repository" -Value @{
            Value  = $starterModuleUrl
            Source = "calaculated"
        }
        $inputConfig | Add-Member -MemberType NoteProperty -Name "on_demand_folder_artifact_name" -Value @{
            Value  = $starterReleaseArtifactName
            Source = "calaculated"
        }
        $inputConfig | Add-Member -MemberType NoteProperty -Name "release_version" -Value @{
            Value  = ($starterReleaseTag -eq "local" ? $inputConfig.starter_module_version.Value : $starterReleaseTag)
            Source = "calaculated"
        }

        # Run the bootstrap
        $bootstrapTargetPath = Join-Path $inputConfig.output_folder_path.Value $bootstrapTargetFolder
        $starterTargetPath = Join-Path $inputConfig.output_folder_path.Value $starterFolder

        New-Bootstrap `
            -iac $inputConfig.iac_type.Value `
            -bootstrapDetails $bootstrapDetails `
            -validationConfig $validationConfig `
            -inputConfig $inputConfig `
            -bootstrapTargetPath $bootstrapTargetPath `
            -bootstrapRelease $bootstrapReleaseTag `
            -hasStarter:$hasStarterModule `
            -starterTargetPath $starterTargetPath `
            -starterRelease $starterReleaseTag `
            -starterConfig $starterConfig `
            -autoApprove:$inputConfig.auto_approve.Value `
            -destroy:$inputConfig.destroy.Value `
            -zonesSupport $zonesSupport `
            -writeVerboseLogs:$inputConfig.write_verbose_logs.Value `
            -hclParserToolPath $hclParserToolPath `
            -convertTfvarsToJson:$inputConfig.convert_tfvars_to_json.Value `
            -inputConfigFilePaths $inputConfigFilePaths `
            -starterAdditionalFiles $inputConfig.starter_additional_files.Value
    }

    $ProgressPreference = "Continue"

    return
}
