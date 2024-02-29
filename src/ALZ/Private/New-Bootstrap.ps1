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
        [string] $bootstrapPath,

        [Parameter(Mandatory = $false)]
        [switch] $hasStarter,

        [Parameter(Mandatory = $false)]
        [string] $starterPath,

        [Parameter(Mandatory = $false)]
        [string] $bootstrapRelease,

        [Parameter(Mandatory = $false)]
        [string] $starterRelease,

        [Parameter(Mandatory = $false)]
        [string] $starterPipelineFolder,

        [Parameter(Mandatory = $false)]
        [switch] $autoApprove,

        [Parameter(Mandatory = $false)]
        [switch] $destroy
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {

        # Setup tools
        $hclParserToolPath = Get-HCLParserTool -alzEnvironmentDestination $bootstrapPath -toolVersion "v0.6.0"

        # Setup Cache File Name
        $interfaceCacheFileName = "interface-cache.json"
        $bootstrapCacheFileName = "bootstrap-cache.json"
        $starterCacheFileName = "starter-cache.json"
        $interfaceCachePath = Join-Path -Path $bootstrapPath -ChildPath $interfaceCacheFileName
        $interfaceCachedConfig = Get-ALZConfig -configFilePath $interfaceCachePath
        $bootstrapCachePath = Join-Path -Path $bootstrapPath -ChildPath $bootstrapCacheFileName
        $bootstrapCachedConfig = Get-ALZConfig -configFilePath $bootstrapCachePath
        $starterCachePath = Join-Path -Path $starterPath -ChildPath $starterCacheFileName
        $starterCachedConfig = Get-ALZConfig -configFilePath $starterCachePath

        $bootstrapModulePath = Join-Path -Path $bootstrapPath -ChildPath $bootstrapDetails.Value.location

        # Run upgrade
        Invoke-FullUpgrade `
            -bootstrapModulePath $bootstrapModulePath `
            -bootstrapRelease $bootstrapRelease `
            -bootstrapPath $bootstrapPath `
            -starterRelease $starterRelease `
            -starterPath $starterPath `
            -interfaceCacheFileName $interfaceCacheFileName `
            -bootstrapCacheFileName $bootstrapCacheFileName `
            -starterCacheFileName $starterCacheFileName `
            -autoApprove:$autoApprove.IsPresent

        # Get starter module
        $starter = ""
        $starterModulePath = ""
        $pipelineModulePath = ""

        if($hasStarter) {
            $starter = Request-SpecialInput -type "starter" -starterPath $starterPath -userInputOverrides $userInputOverrides
            $starterModulePath = Join-Path -Path $starterPath -ChildPath $starter
            $pipelineModulePath = Join-Path -Path $starterPath -ChildPath $starterPipelineFolder
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
            $targetVariableFilePath = Join-Path -Path $starterModulePath -ChildPath "variables.tf"
            $starterParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $targetVariableFilePath -hclParserToolPath $hclParserToolPath -validators $bootstrapConfig.validators
        }

        # Filter interface inputs if not in bootstrap or starter
        foreach($inputConfigItem in $inputConfig.inputs.PSObject.Properties) {
            if($inputConfigItem.Value.source -ne "input" -or $inputConfigItem.Value.required -eq $true) {
                continue
            }
            $inputVariable = $inputConfigMapped.PSObject.Properties | Where-Object { $_.Name -eq $inputConfigItem.Name }
            $displayMapFilter = $inputConfigItem.Value.PSObject.Properties | Where-Object { $_.Name -eq "display_map_filter" }
            Write-Verbose $($inputConfigItem | ConvertTo-Json)
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
        $interfaceConfiguration = Request-ALZEnvironmentConfig `
            -configurationParameters $inputConfigMapped `
            -respectOrdering `
            -userInputOverrides $userInputOverrides `
            -userInputDefaultOverrides $interfaceCachedConfig `
            -treatEmptyDefaultAsValid $true `
            -autoApprove:$autoApprove.IsPresent

        # Set computed interface inputs
        $computedInputMapping = @{
            "iac_type"             = $iac
            "module_folder_path"   = $starterModulePath
            "pipeline_folder_path" = $pipelineModulePath
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

        Write-Verbose $($inputConfig.inputs | ConvertTo-Json)
        Write-Verbose $($interfaceConfiguration | ConvertTo-Json)

        foreach($inputConfigItem in $inputConfig.inputs.PSObject.Properties) {
            $inputVariable = $interfaceConfiguration.PSObject.Properties | Where-Object { $_.Name -eq $inputConfigItem.Name }
            if("bootstrap" -in $inputConfigItem.Value.maps_to) {
                $bootstrapComputed | Add-Member -NotePropertyName $inputVariable.Name -NotePropertyValue $inputVariable.Value
            }
            if("starter" -in $inputConfigItem.Value.maps_to) {
                $starterComputed | Add-Member -NotePropertyName $inputVariable.Name -NotePropertyValue $inputVariable.Value
            }
        }

        # Getting the user input for the bootstrap module
        $bootstrapConfiguration = Request-ALZEnvironmentConfig `
            -configurationParameters $bootstrapParameters `
            -respectOrdering `
            -userInputOverrides $userInputOverrides `
            -userInputDefaultOverrides $bootstrapCachedConfig `
            -treatEmptyDefaultAsValid $true `
            -autoApprove:$autoApprove.IsPresent `
            -computedInputs $bootstrapComputed


        Write-InformationColored "The following inputs are specific to the '$starter' starter module that you selected..." -ForegroundColor Green -InformationAction Continue

        # Getting the user input for the starter module
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
        Write-TfvarsFile -tfvarsFilePath $bootstrapTfvarsPath -configuration $bootstrapConfiguration
        Write-TfvarsFile -tfvarsFilePath $starterTfvarsPath -configuration $starterConfiguration

        # Caching the bootstrap and starter module values paths for retry / upgrade scenarios
        Write-ConfigurationCache -filePath $bootstrapCachePath -configuration $bootstrapConfiguration
        Write-ConfigurationCache -filePath $starterCachePath -configuration $starterConfiguration

        # Running terraform init and apply
        Write-InformationColored "Thank you for providing those inputs, we are now initializing and applying Terraform to bootstrap your environment..." -ForegroundColor Green -InformationAction Continue

        if($autoApprove) {
            Invoke-Terraform -moduleFolderPath $bootstrapModulePath -tfvarsFileName "override.tfvars" -autoApprove -destroy:$destroy.IsPresent
        } else {
            Write-InformationColored "Once the plan is complete you will be prompted to confirm the apply. You must enter 'yes' to apply." -ForegroundColor Green -InformationAction Continue
            Invoke-Terraform -moduleFolderPath $bootstrapModulePath -tfvarsFileName "override.tfvars" -destroy:$destroy.IsPresent
        }
    }
}