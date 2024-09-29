function New-Bootstrap {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $iac,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $bootstrapDetails,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $validationConfig,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $inputConfig,

        [Parameter(Mandatory = $false)]
        [string] $bootstrapTargetPath,

        [Parameter(Mandatory = $false)]
        [switch] $hasStarter,

        [Parameter(Mandatory = $false)]
        [string] $starterTargetPath,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $starterConfig = $null,

        [Parameter(Mandatory = $false)]
        [string] $bootstrapRelease,

        [Parameter(Mandatory = $false)]
        [string] $starterRelease,

        [Parameter(Mandatory = $false)]
        [switch] $autoApprove,

        [Parameter(Mandatory = $false)]
        [switch] $destroy,

        [Parameter(Mandatory = $false)]
        [string] $starter = "",

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $zonesSupport = $null,

        [Parameter(Mandatory = $false)]
        [hashtable] $computedInputs,

        [Parameter(Mandatory = $false, HelpMessage = "An extra level of logging that is turned off by default for easier debugging.")]
        [switch]
        $writeVerboseLogs,

        [Parameter(Mandatory = $false)]
        [string]
        $hclParserToolPath
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {

        $bootstrapPath = Join-Path $bootstrapTargetPath $bootstrapRelease
        $starterPath = Join-Path $starterTargetPath $starterRelease
        $bootstrapModulePath = Join-Path -Path $bootstrapPath -ChildPath $bootstrapDetails.Value.location

        Write-Verbose "Bootstrap Module Path: $bootstrapModulePath"

        # Run upgrade
        Invoke-FullUpgrade `
            -bootstrapModuleFolder $bootstrapDetails.Value.location `
            -bootstrapRelease $bootstrapRelease `
            -bootstrapPath $bootstrapTargetPath `
            -autoApprove:$autoApprove.IsPresent

        # Get starter module
        $starterModulePath = ""

        if($hasStarter) {
            if($starter -eq "") {
                $starter = Request-SpecialInput -type "starter" -starterConfig $starterConfig -inputConfig $inputConfig
            }

            Write-Verbose "Selected Starter: $starter"

            $starterModulePath = (Resolve-Path (Join-Path -Path $starterPath -ChildPath $starterConfig.starter_modules.$starter.location)).Path

            Write-Verbose "Starter Module Path: $starterModulePath"
        }

        # Getting configuration for the bootstrap module user input
        $bootstrapParameters = [PSCustomObject]@{}

        Write-Verbose "Getting the bootstrap configuration for user input..."
        $terraformFiles = Get-ChildItem -Path $bootstrapModulePath -Filter "*.tf" -File
        foreach($terraformFile in $terraformFiles) {
            $bootstrapParameters = Convert-HCLVariablesToInputConfig -targetVariableFile $terraformFile.FullName -hclParserToolPath $hclParserToolPath -validators $validationConfig -appendToObject $bootstrapParameters
        }
        #Write-Verbose "Bootstrap Config: $(ConvertTo-Json $bootstrapParameters -Depth 100)"

        # Getting the configuration for the starter module user input
        $starterParameters  = [PSCustomObject]@{}

        if($hasStarter) {
            if($iac -eq "terraform") {
                $terraformFiles = Get-ChildItem -Path $starterModulePath -Filter "*.tf" -File
                foreach($terraformFile in $terraformFiles) {
                    $starterParameters = Convert-HCLVariablesToInputConfig -targetVariableFile $terraformFile.FullName -hclParserToolPath $hclParserToolPath -validators $validationConfig -appendToObject $starterParameters
                }
            }

            if($iac -eq "bicep") {
                $starterParameters = Convert-BicepConfigToInputConfig -inputConfig $starterConfig.starter_modules.$starter -validators $validationConfig
            }
        }

        # Set computed inputs
        #Write-Verbose "Input config: $(ConvertTo-Json $inputConfig -Depth 100)"
        $computedInputs["starter_module_name"] = $starter
        $computedInputs["module_folder_path"] = $starterModulePath
        $computedInputs["availability_zones_bootstrap"] = @(Get-AvailabilityZonesSupport -region $inputConfig.bootstrap_location -zonesSupport $zonesSupport)

        if($inputConfig.PSObject.Properties.Name -contains "starter_locations") {
            $computedInputs["availability_zones_starter"] = @()
            foreach($region in $inputConfig.starter_locations) {
                $computedInputs["availability_zones_starter"] += @(Get-AvailabilityZonesSupport -region $region -zonesSupport $zonesSupport)
            }
            Write-Verbose "Computed availability zones for starter: $(ConvertTo-Json $computedInputs["availability_zones_starter"] -Depth 100)"
        }

        Write-Verbose "Computed Inputs: $(ConvertTo-Json $computedInputs -Depth 100)"

        # Getting the input for the bootstrap module
        $bootstrapConfiguration = Set-Config `
            -configurationParameters $bootstrapParameters `
            -inputConfig $inputConfig `
            -computedInputs $computedInputs

        # Getting the input for the starter module
        $starterConfiguration = Set-Config `
            -configurationParameters $starterParameters `
            -inputConfig $inputConfig `
            -computedInputs $computedInputs `
            -copyEnvVarToConfig

        # Creating the tfvars files for the bootstrap and starter module
        $tfVarsFileName = "terraform.tfvars.json"
        $bootstrapTfvarsPath = Join-Path -Path $bootstrapModulePath -ChildPath $tfVarsFileName
        $starterTfvarsPath = Join-Path -Path $starterModulePath -ChildPath "terraform.tfvars.json"
        $starterBicepVarsPath = Join-Path -Path $starterModulePath -ChildPath "parameters.json"

        # Write the tfvars file for the bootstrap and starter module
        Write-TfvarsJsonFile -tfvarsFilePath $bootstrapTfvarsPath -configuration $bootstrapConfiguration

        if($iac -eq "terraform") {
            Remove-TerraformMetaFileSet -path $starterModulePath -writeVerboseLogs:$writeVerboseLogs.IsPresent
            Write-TfvarsJsonFile -tfvarsFilePath $starterTfvarsPath -configuration $starterConfiguration
        }

        if($iac -eq "bicep") {
            Copy-ParametersFileCollection -starterPath $starterModulePath -configFiles $starterConfig.starter_modules.$starter.deployment_files
            Set-ComputedConfiguration -configuration $starterConfiguration
            Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination $starterModulePath -configuration $starterConfiguration
            Write-JsonFile -jsonFilePath $starterBicepVarsPath -configuration $starterConfiguration

            # Remove unrequired files
            $foldersOrFilesToRetain = $starterConfig.starter_modules.$starter.folders_or_files_to_retain
            $foldersOrFilesToRetain += "parameters.json"
            $foldersOrFilesToRetain += "config"
            $foldersOrFilesToRetain += "starter-cache.json"

            foreach($deployment_file in $starterConfig.starter_modules.$starter.deployment_files) {
                $foldersOrFilesToRetain += $deployment_file.templateParametersSourceFilePath
            }

            $subFoldersOrFilesToRemove = $starterConfig.starter_modules.$starter.subfolders_or_files_to_remove

            Remove-UnrequiredFileSet -path $starterModulePath -foldersOrFilesToRetain $foldersOrFilesToRetain -subFoldersOrFilesToRemove $subFoldersOrFilesToRemove -writeVerboseLogs:$writeVerboseLogs.IsPresent
        }

        # Running terraform init and apply
        Write-InformationColored "Thank you for providing those inputs, we are now initializing and applying Terraform to bootstrap your environment..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

        if($autoApprove) {
            Invoke-Terraform -moduleFolderPath $bootstrapModulePath -autoApprove -destroy:$destroy.IsPresent
        } else {
            Write-InformationColored "Once the plan is complete you will be prompted to confirm the apply." -ForegroundColor Green -NewLineBefore -InformationAction Continue
            Invoke-Terraform -moduleFolderPath $bootstrapModulePath -destroy:$destroy.IsPresent
        }

        Write-InformationColored "Bootstrap has completed successfully! Thanks for using our tool. Head over to Phase 3 in the documentation to continue..." -ForegroundColor Green -NewLineBefore -InformationAction Continue
    }
}