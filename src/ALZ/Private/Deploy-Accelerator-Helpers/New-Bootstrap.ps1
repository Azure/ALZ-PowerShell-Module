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
        [switch] $planOnly,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $zonesSupport = $null,

        [Parameter(Mandatory = $false, HelpMessage = "An extra level of logging that is turned off by default for easier debugging.")]
        [switch]
        $writeVerboseLogs,

        [Parameter(Mandatory = $false)]
        [string]
        $hclParserToolPath,

        [Parameter(Mandatory = $false)]
        [switch]
        $convertTfvarsToJson,

        [Parameter(Mandatory = $false)]
        [string[]]
        $inputConfigFilePaths = @(),

        [Parameter(Mandatory = $false)]
        [string[]]
        $starterAdditionalFiles = @()
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
        $starterRootModuleFolderPath = ""
        $starterFoldersToRetain = @()

        if($hasStarter) {
            if($inputConfig.starter_module_name.Value -eq "") {
                $inputConfig.starter_module_name = @{
                    Value  = Request-SpecialInput -type "starter" -starterConfig $starterConfig
                    Source = "user"
                }
            }

            $chosenStarterConfig = $starterConfig.starter_modules.Value.$($inputConfig.starter_module_name.Value)

            Write-Verbose "Selected Starter: $($inputConfig.starter_module_name.Value))"
            $starterModulePath = (Resolve-Path (Join-Path -Path $starterPath -ChildPath $chosenStarterConfig.location)).Path
            $starterRootModuleFolderPath = $starterModulePath
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
                $inputConfig | Add-Member -NotePropertyName "root_module_folder_relative_path" -NotePropertyValue @{
                    Value  = $starterRootModuleFolder
                    Source = "caluated"
                }

                # Set the starter root module folder full path
                $starterRootModuleFolderPath = Join-Path -Path $starterModulePath -ChildPath $starterRootModuleFolder

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
                $terraformFiles = Get-ChildItem -Path $starterRootModuleFolderPath -Filter "*.tf" -File
                foreach($terraformFile in $terraformFiles) {
                    $starterParameters = Convert-HCLVariablesToInputConfig -targetVariableFile $terraformFile.FullName -hclParserToolPath $hclParserToolPath -validators $validationConfig -appendToObject $starterParameters
                }
            }

            if($iac -eq "bicep") {
                $starterParameters = Convert-BicepConfigToInputConfig -bicepConfig $starterConfig.starter_modules.Value.$($inputConfig.starter_module_name.Value) -validators $validationConfig
            }
        }

        # Set computed inputs
        $inputConfig | Add-Member -NotePropertyName "module_folder_path" -NotePropertyValue @{
            Value  = $starterModulePath
            Source = "calculated"
        }
        $inputConfig | Add-Member -NotePropertyName "availability_zones_bootstrap" -NotePropertyValue @{
            Value  = @(Get-AvailabilityZonesSupport -region $inputConfig.bootstrap_location.Value -zonesSupport $zonesSupport)
            Source = "calculated"
        }

        if($inputConfig.PSObject.Properties.Name -contains "starter_location" -and $inputConfig.PSObject.Properties.Name -notcontains "starter_locations") {
            Write-Verbose "Converting starter_location $($inputConfig.starter_location.Value) to starter_locations..."
            $inputConfig | Add-Member -NotePropertyName "starter_locations" -NotePropertyValue @{
                Value  = @($inputConfig.starter_location.Value)
                Source = "calculated"
            }
        }

        if($inputConfig.PSObject.Properties.Name -contains "starter_locations") {
            $availabilityZonesStarter = @()
            foreach($region in $inputConfig.starter_locations.Value) {
                $availabilityZonesStarter += , @(Get-AvailabilityZonesSupport -region $region -zonesSupport $zonesSupport)
            }
            $inputConfig | Add-Member -NotePropertyName "availability_zones_starter" -NotePropertyValue @{
                Value  = $availabilityZonesStarter
                Source = "calculated"
            }
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
        $starterTfvarsPath = Join-Path -Path $starterRootModuleFolderPath -ChildPath "terraform.tfvars.json"
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
            if($convertTfvarsToJson) {
                Write-TfvarsJsonFile -tfvarsFilePath $starterTfvarsPath -configuration $starterConfiguration
            } else {
                $inputsFromTfvars = $inputConfig.PSObject.Properties | Where-Object { $_.Value.Source -eq ".tfvars" } | Select-Object -ExpandProperty Name
                Write-TfvarsJsonFile -tfvarsFilePath $starterTfvarsPath -configuration $starterConfiguration -skipItems $inputsFromTfvars
                foreach($inputConfigFilePath in $inputConfigFilePaths | Where-Object { $_ -like "*.tfvars" }) {
                    $fileName = [System.IO.Path]::GetFileName($inputConfigFilePath)
                    $fileName = $fileName.Replace(".tfvars", ".auto.tfvars")
                    $destination = Join-Path -Path $starterRootModuleFolderPath -ChildPath $fileName
                    Write-Verbose "Copying tfvars file $inputConfigFilePath to $destination"
                    Copy-Item -Path $inputConfigFilePath -Destination $destination -Force
                }
            }

            # Copy additional files
            foreach($additionalFile in $starterAdditionalFiles) {
                if(Test-Path $additionalFile -PathType Container) {
                    $folderName = ([System.IO.DirectoryInfo]::new($additionalFile)).Name
                    $destination = Join-Path -Path $starterRootModuleFolderPath -ChildPath $folderName
                    Write-Verbose "Copying folder $additionalFile to $destination"
                    Copy-Item -Path "$additionalFile/*" -Destination $destination -Recurse -Force
                } else {
                    $fileName = [System.IO.Path]::GetFileName($inputConfigFilePath)
                    $destination = Join-Path -Path $starterRootModuleFolderPath -ChildPath $fileName
                    Write-Verbose "Copying file $additionalFile to $destination"
                    Copy-Item -Path $additionalFile -Destination $destination -Force
                }
            }
        }

        if($iac -eq "bicep") {
            Copy-ParametersFileCollection -starterPath $starterModulePath -configFiles $starterConfig.starter_modules.Value.$($inputConfig.starter_module_name.Value).deployment_files
            Set-ComputedConfiguration -configuration $starterConfiguration
            Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination $starterModulePath -configuration $starterConfiguration
            Write-JsonFile -jsonFilePath $starterBicepVarsPath -configuration $starterConfiguration

            # Remove unrequired files
            $foldersOrFilesToRetain = $starterConfig.starter_modules.Value.$($inputConfig.starter_module_name.Value).folders_or_files_to_retain
            $foldersOrFilesToRetain += "parameters.json"
            $foldersOrFilesToRetain += "config"
            $foldersOrFilesToRetain += "starter-cache.json"

            foreach($deployment_file in $starterConfig.starter_modules.Value.$($inputConfig.starter_module_name.Value).deployment_files) {
                $foldersOrFilesToRetain += $deployment_file.templateParametersSourceFilePath
            }

            $subFoldersOrFilesToRemove = $starterConfig.starter_modules.Value.$($inputConfig.starter_module_name.Value).subfolders_or_files_to_remove

            Remove-UnrequiredFileSet -path $starterModulePath -foldersOrFilesToRetain $foldersOrFilesToRetain -subFoldersOrFilesToRemove $subFoldersOrFilesToRemove -writeVerboseLogs:$writeVerboseLogs.IsPresent
        }

        # Running terraform init and apply
        Write-InformationColored "Thank you for providing those inputs, we are now initializing and applying Terraform to bootstrap your environment..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

        if($autoApprove) {
            Invoke-Terraform -moduleFolderPath $bootstrapModulePath -autoApprove -destroy:$destroy.IsPresent -planOnly:$planOnly.IsPresent
        } else {
            Write-InformationColored "Once the plan is complete you will be prompted to confirm the apply." -ForegroundColor Green -NewLineBefore -InformationAction Continue
            Invoke-Terraform -moduleFolderPath $bootstrapModulePath -destroy:$destroy.IsPresent -planOnly:$planOnly.IsPresent
        }

        Write-InformationColored "Bootstrap has completed successfully! Thanks for using our tool. Head over to Phase 3 in the documentation to continue..." -ForegroundColor Green -NewLineBefore -InformationAction Continue
    }
}