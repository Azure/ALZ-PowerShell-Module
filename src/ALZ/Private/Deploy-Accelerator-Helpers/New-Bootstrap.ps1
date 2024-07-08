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
        [PSCustomObject] $userInputOverrides = $null,

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
        [PSCustomObject] $zonesSupport = $null
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {

        $bootstrapPath = Join-Path $bootstrapTargetPath $bootstrapRelease
        $starterPath = Join-Path $starterTargetPath $starterRelease

        # Setup tools
        $hclParserToolPath = Get-HCLParserTool -alzEnvironmentDestination $bootstrapPath -toolVersion "v0.6.0"

        # Setup Cache File Names
        $interfaceCacheFileName = "interface-cache.json"
        $bootstrapCacheFileName = "bootstrap-cache.json"
        $starterCacheFileName = "starter-cache.json"
        $interfaceCachePath = Join-Path -Path $bootstrapPath -ChildPath $interfaceCacheFileName
        $bootstrapCachePath = Join-Path -Path $bootstrapPath -ChildPath $bootstrapCacheFileName
        $starterCachePath = Join-Path -Path $starterPath -ChildPath $starterCacheFileName
        $bootstrapModulePath = Join-Path -Path $bootstrapPath -ChildPath $bootstrapDetails.Value.location

        Write-Verbose "Bootstrap Module Path: $bootstrapModulePath"

        # Run upgrade
        Invoke-FullUpgrade `
            -bootstrapModuleFolder $bootstrapDetails.Value.location `
            -bootstrapRelease $bootstrapRelease `
            -bootstrapPath $bootstrapTargetPath `
            -starterRelease $starterRelease `
            -starterPath $starterTargetPath `
            -interfaceCacheFileName $interfaceCacheFileName `
            -bootstrapCacheFileName $bootstrapCacheFileName `
            -starterCacheFileName $starterCacheFileName `
            -autoApprove:$autoApprove.IsPresent

        # Get cached inputs
        $interfaceCachedConfig = Get-ALZConfig -configFilePath $interfaceCachePath
        $bootstrapCachedConfig = Get-ALZConfig -configFilePath $bootstrapCachePath
        $starterCachedConfig = Get-ALZConfig -configFilePath $starterCachePath

        # Get starter module
        $starterModulePath = ""

        if($hasStarter) {
            if($starter -eq "") {
                $starter = Request-SpecialInput -type "starter" -starterConfig $starterConfig -userInputOverrides $userInputOverrides
            }

            Write-Verbose "Selected Starter: $starter"

            $starterModulePath = Resolve-Path (Join-Path -Path $starterPath -ChildPath $starterConfig.starter_modules.$starter.location)

            Write-Verbose "Starter Module Path: $starterModulePath"
        }

        # Getting the configuration for the interface user input
        Write-Verbose "Getting the interface configuration for user input..."
        $inputConfigMapped = Convert-InterfaceInputToUserInputConfig -inputConfig $inputConfig -validators $validationConfig

        # Getting configuration for the bootstrap module user input
        $bootstrapParameters = [PSCustomObject]@{}

        Write-Verbose "Getting the bootstrap configuration for user input..."
        foreach($inputVariablesFile in $bootstrapDetails.Value.input_variable_files) {
            $inputVariablesFilePath = Join-Path -Path $bootstrapModulePath -ChildPath $inputVariablesFile
            $bootstrapParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $inputVariablesFilePath -hclParserToolPath $hclParserToolPath -validators $validationConfig -appendToObject $bootstrapParameters
        }
        Write-Verbose "Getting the bootstrap configuration computed interface input..."
        foreach($interfaceVariablesFile in $bootstrapDetails.Value.interface_variable_files) {
            $inputVariablesFilePath = Join-Path -Path $bootstrapModulePath -ChildPath $interfaceVariablesFile
            $bootstrapParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $inputVariablesFilePath -hclParserToolPath $hclParserToolPath -validators $validationConfig -appendToObject $bootstrapParameters -allComputedInputs
        }

        # Getting the configuration for the starter module user input
        $starterParameters  = [PSCustomObject]@{}

        if($hasStarter) {
            if($iac -eq "terraform") {
                $targetVariableFilePath = Join-Path -Path $starterModulePath -ChildPath "variables.tf"
                $starterParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $targetVariableFilePath -hclParserToolPath $hclParserToolPath -validators $validationConfig
            }

            if($iac -eq "bicep") {
                $starterParameters = Convert-InterfaceInputToUserInputConfig -inputConfig $starterConfig.starter_modules.$starter -validators $validationConfig
            }
        }

        # Filter interface inputs if not in bootstrap or starter
        foreach($inputConfigItem in $inputConfig.inputs.PSObject.Properties) {
            if($inputConfigItem.Value.source -ne "input" -or $inputConfigItem.Value.required -eq $true) {
                continue
            }
            $inputVariable = $inputConfigMapped.PSObject.Properties | Where-Object { $_.Name -eq $inputConfigItem.Name }
            $displayMapFilter = $inputConfigItem.Value.PSObject.Properties | Where-Object { $_.Name -eq "display_map_filter" }
            $hasDisplayMapFilter = $null -ne $displayMapFilter
            Write-Verbose "$($inputConfigItem.Name) has display map filter $hasDisplayMapFilter"

            $inBootstrapOrStarter = $false
            if("bootstrap" -in $inputConfigItem.Value.maps_to) {
                $checkFilter = !$hasDisplayMapFilter -or ($hasDisplayMapFilter -and "bootstrap" -in $displayMapFilter.Value)

                if($checkFilter) {
                    Write-Verbose "Checking bootstrap for $($inputConfigItem.Name)"
                    $boostrapParameter = $bootstrapParameters.PSObject.Properties | Where-Object { $_.Name -eq $inputVariable.Name }
                    if($null -ne $boostrapParameter) {
                        $inBootstrapOrStarter = $true
                    }
                }
            }
            if("starter" -in $inputConfigItem.Value.maps_to) {
                $checkFilter = !$hasDisplayMapFilter -or ($hasDisplayMapFilter -and "starter" -in $displayMapFilter.Value)

                if($checkFilter) {
                    Write-Verbose "Checking starter for $($inputConfigItem.Name)"
                    $starterParameter = $starterParameters.PSObject.Properties | Where-Object { $_.Name -eq $inputVariable.Name }
                    if($null -ne $starterParameter) {
                        $inBootstrapOrStarter = $true
                    }
                }
            }

            if(!$inBootstrapOrStarter) {
                $inputVariable.Value.Type = "SkippedInput"
            }
        }

        # Prompt user for interface inputs
        Write-InformationColored "The following shared inputs are for the '$($bootstrapDetails.Name)' bootstrap and '$starter' starter module that you selected:" -ForegroundColor Green -NewLineBefore -InformationAction Continue
        $interfaceConfiguration = Request-ALZEnvironmentConfig `
            -configurationParameters $inputConfigMapped `
            -respectOrdering `
            -userInputOverrides $userInputOverrides `
            -userInputDefaultOverrides $interfaceCachedConfig `
            -treatEmptyDefaultAsValid $true `
            -autoApprove:$autoApprove.IsPresent

        # Set computed interface inputs
        $computedInputMapping = @{
            "iac_type"            = $iac
            "module_folder_path"  = $starterModulePath
            "starter_module_name" = $starter
        }

        foreach($inputConfigItem in $inputConfig.inputs.PSObject.Properties) {
            if($inputConfigItem.Value.source -eq "powershell") {

                $inputVariable = $interfaceConfiguration.PSObject.Properties | Where-Object { $_.Name -eq $inputConfigItem.Name }
                $inputValue = $computedInputMapping[$inputConfigItem.Name]
                Write-Verbose "Setting $($inputConfigItem.Name) to $inputValue"
                $inputVariable.Value.Value = $inputValue
            }
        }

        # Split interface inputs
        $bootstrapComputed = [PSCustomObject]@{}
        $starterComputed = [PSCustomObject]@{}

        foreach($inputConfigItem in $inputConfig.inputs.PSObject.Properties) {
            $inputVariable = $interfaceConfiguration.PSObject.Properties | Where-Object { $_.Name -eq $inputConfigItem.Name }
            if("bootstrap" -in $inputConfigItem.Value.maps_to) {
                $bootstrapComputed | Add-Member -NotePropertyName $inputVariable.Name -NotePropertyValue $inputVariable.Value
            }

            if("starter" -in $inputConfigItem.Value.maps_to) {
                if($iac -eq "terraform") {
                    $starterComputed | Add-Member -NotePropertyName $inputVariable.Name -NotePropertyValue $inputVariable.Value
                }

                if($iac -eq "bicep") {
                    if($inputConfigItem.Value.PSObject.Properties.Name -contains "bicep_alias") {
                        Write-Verbose "Setting computed bicep alias $($inputConfigItem.Value.bicep_alias)"
                        $starterComputed | Add-Member -NotePropertyName $inputConfigItem.Value.bicep_alias -NotePropertyValue $inputVariable.Value
                    } else {
                        $starterComputed | Add-Member -NotePropertyName $inputVariable.Name -NotePropertyValue $inputVariable.Value
                    }
                }
            }
        }

        # Getting the user input for the bootstrap module
        Write-InformationColored "The following inputs are specific to the '$($bootstrapDetails.Name)' bootstrap module that you selected:" -ForegroundColor Green -NewLineBefore -InformationAction Continue
        $bootstrapConfiguration = Request-ALZEnvironmentConfig `
            -configurationParameters $bootstrapParameters `
            -respectOrdering `
            -userInputOverrides $userInputOverrides `
            -userInputDefaultOverrides $bootstrapCachedConfig `
            -treatEmptyDefaultAsValid $true `
            -autoApprove:$autoApprove.IsPresent `
            -computedInputs $bootstrapComputed

        # Getting the user input for the starter module
        Write-InformationColored "The following inputs are specific to the '$starter' starter module that you selected:" -ForegroundColor Green -NewLineBefore -InformationAction Continue
        $starterConfiguration = Request-ALZEnvironmentConfig `
            -configurationParameters $starterParameters `
            -respectOrdering `
            -userInputOverrides $userInputOverrides `
            -userInputDefaultOverrides $starterCachedConfig `
            -treatEmptyDefaultAsValid $true `
            -autoApprove:$autoApprove.IsPresent `
            -computedInputs $starterComputed

        # Creating the tfvars files for the bootstrap and starter module
        $bootstrapTfvarsPath = Join-Path -Path $bootstrapModulePath -ChildPath "override.tfvars"
        $starterTfvarsPath = Join-Path -Path $starterModulePath -ChildPath "terraform.tfvars"
        $starterBicepVarsPath = Join-Path -Path $starterModulePath -ChildPath "parameters.json"
        Write-TfvarsFile -tfvarsFilePath $bootstrapTfvarsPath -configuration $bootstrapConfiguration

        if($iac -eq "terraform") {
            Write-TfvarsFile -tfvarsFilePath $starterTfvarsPath -configuration $starterConfiguration
        }

        if($iac -eq "bicep") {
            Copy-ParametersFileCollection -starterPath $starterModulePath -configFiles $starterConfig.starter_modules.$starter.deployment_files
            Set-ComputedConfiguration -configuration $starterConfiguration
            Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination $starterModulePath -configuration $starterConfiguration
            Add-AvailabilityZonesBicepParameter -alzEnvironmentDestination $starterModulePath -zonesSupport $zonesSupport
            Write-JsonFile -jsonFilePath $starterBicepVarsPath -configuration $starterConfiguration

            # Remove unrequired files
            $foldersOrFilesToRetain = $starterConfig.starter_modules.$starter.folders_or_files_to_retain
            $foldersOrFilesToRetain += "parameters.json"
            $foldersOrFilesToRetain += "config"
            $foldersOrFilesToRetain += "starter-cache.json"

            $subFoldersOrFilesToRemove = $starterConfig.starter_modules.$starter.subfolders_or_files_to_remove

            Remove-UnrequiredFileSet -path $starterModulePath -foldersOrFilesToRetain $foldersOrFilesToRetain -subFoldersOrFilesToRemove $subFoldersOrFilesToRemove
        }

        # Caching the bootstrap and starter module values paths for retry / upgrade scenarios
        Write-ConfigurationCache -filePath $interfaceCachePath -configuration $interfaceConfiguration
        Write-ConfigurationCache -filePath $bootstrapCachePath -configuration $bootstrapConfiguration
        Write-ConfigurationCache -filePath $starterCachePath -configuration $starterConfiguration

        # Running terraform init and apply
        Write-InformationColored "Thank you for providing those inputs, we are now initializing and applying Terraform to bootstrap your environment..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

        if($autoApprove) {
            Invoke-Terraform -moduleFolderPath $bootstrapModulePath -tfvarsFileName "override.tfvars" -autoApprove -destroy:$destroy.IsPresent
        } else {
            Write-InformationColored "Once the plan is complete you will be prompted to confirm the apply. You must enter 'yes' to apply." -ForegroundColor Green -NewLineBefore -InformationAction Continue
            Invoke-Terraform -moduleFolderPath $bootstrapModulePath -tfvarsFileName "override.tfvars" -destroy:$destroy.IsPresent
        }
    }
}