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
        [PSCustomObject] $zonesSupport = $null,

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
        $starterRootModuleFolder = ""
        $starterFoldersToRetain = @()

        if($hasStarter) {
            if($inputConfig.starter_module_name -eq "") {
                $inputConfig.starter_module_name = Request-SpecialInput -type "starter" -starterConfig $starterConfig
            }

            $chosenStarterConfig = $starterConfig.starter_modules.$($inputConfig.starter_module_name)

            Write-Verbose "Selected Starter: $($inputConfig.starter_module_name))"
            $starterModulePath = (Resolve-Path (Join-Path -Path $starterPath -ChildPath $chosenStarterConfig.location)).Path
            Write-Verbose "Starter Module Path: $starterModulePath"

            if($chosenStarterConfig.PSObject.Properties.Name -contains "additional_retained_folders") {
                $starterFoldersToRetain = $chosenStarterConfig.additional_retained_folders
                Write-Verbose "Starter Additional folders to retain: $($starterFoldersToRetain -join ",")"
            }

            if($chosenStarterConfig.PSObject.Properties.Name -contains "root_module_folder") {
                $starterRootModuleFolder = $chosenStarterConfig.root_module_folder

                # Retain the root module folder
                $starterFoldersToRetain += $starterRootModuleFolder

                # Add the root module folder to bootstrap input config
                $inputConfig | Add-Member -NotePropertyName "root_module_folder_relative_path" -NotePropertyValue $starterRootModuleFolder

                Write-Verbose "Starter root module folder: $starterRootModuleFolder"
                Write-Verbose "Starter final folders to retain: $($starterFoldersToRetain -join ",")"
            }
        }

        # Getting configuration for the bootstrap module user input
        $bootstrapParameters = [PSCustomObject]@{}

        Write-Verbose "Getting the bootstrap configuration..."
        $terraformFiles = Get-ChildItem -Path $bootstrapModulePath -Filter "*.tf" -File
        foreach($terraformFile in $terraformFiles) {
            $bootstrapParameters = Convert-HCLVariablesToInputConfig -targetVariableFile $terraformFile.FullName -hclParserToolPath $hclParserToolPath -validators $validationConfig -appendToObject $bootstrapParameters
        }

        # Getting the configuration for the starter module user input
        $starterParameters  = [PSCustomObject]@{}

        if($hasStarter) {
            Write-Verbose "Getting the starter configuration..."
            if($iac -eq "terraform") {
                $terraformFiles = Get-ChildItem -Path $starterModulePath -Filter "*.tf" -File
                foreach($terraformFile in $terraformFiles) {
                    $starterParameters = Convert-HCLVariablesToInputConfig -targetVariableFile $terraformFile.FullName -hclParserToolPath $hclParserToolPath -validators $validationConfig -appendToObject $starterParameters
                }
            }

            if($iac -eq "bicep") {
                $starterParameters = Convert-BicepConfigToInputConfig -bicepConfig $starterConfig.starter_modules.$($inputConfig.starter_module_name) -validators $validationConfig
            }
        }

        # Set computed inputs
        $inputConfig | Add-Member -NotePropertyName "module_folder_path" -NotePropertyValue $starterModulePath
        $inputConfig | Add-Member -NotePropertyName "availability_zones_bootstrap" -NotePropertyValue @(Get-AvailabilityZonesSupport -region $inputConfig.bootstrap_location -zonesSupport $zonesSupport)

        if($inputConfig.PSObject.Properties.Name -contains "starter_location" -and $inputConfig.PSObject.Properties.Name -notcontains "starter_locations") {
            Write-Verbose "Converting starter_location $($inputConfig.starter_location) to starter_locations..."
            $inputConfig | Add-Member -NotePropertyName "starter_locations" -NotePropertyValue @($inputConfig.starter_location)
        }

        if($inputConfig.PSObject.Properties.Name -contains "starter_locations") {
            $availabilityZonesStarter = @()
            foreach($region in $inputConfig.starter_locations) {
                $availabilityZonesStarter += , @(Get-AvailabilityZonesSupport -region $region -zonesSupport $zonesSupport)
            }
            $inputConfig | Add-Member -NotePropertyName "availability_zones_starter" -NotePropertyValue $availabilityZonesStarter
        }

        Write-Verbose "Final Input config: $(ConvertTo-Json $inputConfig -Depth 100)"

        # Getting the input for the bootstrap module
        Write-Verbose "Setting the configuration for the bootstrap module..."
        $bootstrapConfiguration = Set-Config `
            -configurationParameters $bootstrapParameters `
            -inputConfig $inputConfig

        # Getting the input for the starter module
        Write-Verbose "Setting the configuration for the starter module..."
        $starterConfiguration = Set-Config `
            -configurationParameters $starterParameters `
            -inputConfig $inputConfig `
            -copyEnvVarToConfig

        Write-Verbose "Final Starter Parameters: $(ConvertTo-Json $starterParameters -Depth 100)"

        # Creating the tfvars files for the bootstrap and starter module
        $tfVarsFileName = "terraform.tfvars.json"
        $bootstrapTfvarsPath = Join-Path -Path $bootstrapModulePath -ChildPath $tfVarsFileName
        $starterTfvarsPath = Join-Path -Path $starterModulePath -ChildPath "terraform.tfvars.json"
        $starterBicepVarsPath = Join-Path -Path $starterModulePath -ChildPath "parameters.json"

        # Write the tfvars file for the bootstrap and starter module
        Write-TfvarsJsonFile -tfvarsFilePath $bootstrapTfvarsPath -configuration $bootstrapConfiguration

        if($iac -eq "terraform") {
            if($starterFoldersToRetain.Length -gt 0) {
                Write-Verbose "Removing unwanted folders from the starter module..."
                $folders = Get-ChildItem -Path $starterModulePath -Directory
                foreach($folder in $folders) {
                    if($starterFoldersToRetain -notcontains $folder.Name) {
                        Write-Verbose "Removing folder: $($folder.FullName)"
                        Remove-Item -Path $folder.FullName -Recurse -Force
                    } else {
                        Write-Verbose "Retaining folder: $($folder.FullName)"
                        Remove-TerraformMetaFileSet -path $folder.FullName -writeVerboseLogs:$writeVerboseLogs.IsPresent
                    }
                }
            }
            Remove-TerraformMetaFileSet -path $starterModulePath -writeVerboseLogs:$writeVerboseLogs.IsPresent
            Write-TfvarsJsonFile -tfvarsFilePath $starterTfvarsPath -configuration $starterConfiguration
        }

        if($iac -eq "bicep") {
            Copy-ParametersFileCollection -starterPath $starterModulePath -configFiles $starterConfig.starter_modules.$($inputConfig.starter_module_name).deployment_files
            Set-ComputedConfiguration -configuration $starterConfiguration
            Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination $starterModulePath -configuration $starterConfiguration
            Write-JsonFile -jsonFilePath $starterBicepVarsPath -configuration $starterConfiguration

            # Remove unrequired files
            $foldersOrFilesToRetain = $starterConfig.starter_modules.$($inputConfig.starter_module_name).folders_or_files_to_retain
            $foldersOrFilesToRetain += "parameters.json"
            $foldersOrFilesToRetain += "config"
            $foldersOrFilesToRetain += "starter-cache.json"

            foreach($deployment_file in $starterConfig.starter_modules.$($inputConfig.starter_module_name).deployment_files) {
                $foldersOrFilesToRetain += $deployment_file.templateParametersSourceFilePath
            }

            $subFoldersOrFilesToRemove = $starterConfig.starter_modules.$($inputConfig.starter_module_name).subfolders_or_files_to_remove

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