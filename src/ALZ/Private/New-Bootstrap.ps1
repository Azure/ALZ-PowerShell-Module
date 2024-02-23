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
        [string] $userInputOverridePath = "",

        [Parameter(Mandatory = $false)]
        [string] $bootstrapPath,

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

        # Get User Input Overrides (used for automated testing purposes and advanced use cases)
        $userInputOverrides = $null
        if($userInputOverridePath -ne "") {
            $userInputOverrides = Get-ALZConfig -configFilePath $userInputOverridePath
        }

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

        # Run upgrade for bootstrap state
        $wasUpgraded = Invoke-Upgrade `
            -targetDirectory $bootstrapModulePath `
            -cacheFileName "terraform.tfstate" `
            -release $bootstrapRelease `
            -autoApprove:$autoApprove.IsPresent

        if($wasUpgraded) {
            # Run upgrade for interface inputs
            Invoke-Upgrade `
                -targetDirectory $bootstrapPath `
                -cacheFileName $interfaceCacheFileName `
                -release $bootstrapRelease `
                -autoApprove:$wasUpgraded

            # Run upgrade for bootstrap inputs
            Invoke-Upgrade `
                -targetDirectory $bootstrapPath `
                -cacheFileName $bootstrapCacheFileName `
                -release $bootstrapRelease `
                -autoApprove:$wasUpgraded

            # Run upgrade for starter
            Invoke-Upgrade `
                -targetDirectory $starterFolderPath `
                -cacheFileName $starterCacheFileName `
                -release $starterRelease `
                -autoApprove:$wasUpgraded
        }

        # Getting the configuration for the interface user input and validators
        $inputConfigMapped = Convert-InterfaceInputToUserInputConfig -inputConfig $inputConfig -validators $validationConfig
        $interfaceConfiguration = Request-ALZEnvironmentConfig -configurationParameters $inputConfigMapped -respectOrdering -userInputOverrides $userInputOverrides -userInputDefaultOverrides $interfaceCachedConfig -treatEmptyDefaultAsValid $true -autoApprove:$autoApprove.IsPresent
        $starterModuleName = $interfaceConfiguration.PsObject.Properties["starter_module"].Value.Value
        $starterModulePath = Join-Path -Path $starterPath -ChildPath $starterModuleName
        $pipelineModulePath = Join-Path -Path $starterPath -ChildPath $bootstrapDetails.Value.pipeline_folder

        $computedInputMapping = @{
            "iac_type" = $iac
            "module_folder_path" = $starterModulePath
            "pipeline_folder_path" = $pipelineModulePath
        }

        $inputConfig.PSCustomObject.Properties | ForEach-Object {
            $property = $_
            if($property.Value.source -eq "powershell") {
                $inputVariable = $interfaceConfiguration | Where-Object { $_.Name -eq $property.Name }
                $inputVariable.Value.Value = $computedInputMapping[$property.Name]
            }
        }

        $hclParserToolPath = Get-HCLParserTool -alzEnvironmentDestination $bootstrapPath -toolVersion "v0.6.0"

        $bootstrapParameters = [PSCustomObject]@{}

        # Getting additional configuration for the bootstrap module user input
        foreach($inputVariablesFile in $bootstrapDetails.Value.input_variable_files) {
            $inputVariablesFilePath = Join-Path -Path $bootstrapModulePath -ChildPath $inputVariablesFile
            $bootstrapParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $inputVariablesFilePath -hclParserToolPath $hclParserToolPath -validators $validationConfig.validators -appendToObject $bootstrapParameters
        }

        Write-InformationColored "Got configuration" -ForegroundColor Green -InformationAction Continue

        # Getting the user input for the bootstrap module
        $bootstrapConfiguration = Request-ALZEnvironmentConfig -configurationParameters $bootstrapParameters -respectOrdering -userInputOverrides $userInputOverrides -userInputDefaultOverrides $bootstrapCachedConfig -treatEmptyDefaultAsValid $true -autoApprove:$autoApprove.IsPresent

        # Getting the configuration for the starter module user input
        $targetVariableFilePath = Join-Path -Path $starterModulePath -ChildPath "variables.tf"
        $starterModuleParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $targetVariableFilePath -hclParserToolPath $hclParserToolPath -validators $bootstrapConfig.validators

        Write-InformationColored "The following inputs are specific to the '$starterTemplate' starter module that you selected..." -ForegroundColor Green -InformationAction Continue

        # Getting the user input for the starter module
        $starterConfiguration = Request-ALZEnvironmentConfig -configurationParameters $starterModuleParameters -respectOrdering -userInputOverrides $userInputOverrides -userInputDefaultOverrides $starterCachedConfig -treatEmptyDefaultAsValid $true -autoApprove:$autoApprove.IsPresent

        # Appending interface configuration to the boostrap and starter configuration
        foreach($inputConfigItem in $inputConfig.PSObject.Properties) {
            $inputVariable = $interfaceConfiguration | Where-Object { $_.Name -eq $inputConfigItem.Name }
            if("bootstrap" -in $inputConfigItem.Value.maps_to) {
                $bootstrapConfiguration | Add-Member -MemberType NoteProperty -Name $inputVariable.Name -Value $inputVariable.Value
            }
            if("starter" -in $inputConfigItem.Value.maps_to) {
                $starterConfiguration | Add-Member -MemberType NoteProperty -Name $inputVariable.Name -Value $inputVariable.Value
            }
        }

        # Creating the tfvars files for the bootstrap and starter module
        $bootstrapTfvarsPath = Join-Path -Path $bootstrapModulePath -ChildPath "override.tfvars"
        $starterTfvarsPath = Join-Path -Path $starterModulePath -ChildPath "terraform.tfvars"
        Write-TfvarsFile -tfvarsFilePath $bootstrapTfvarsPath -configuration $bootstrapConfiguration
        Write-TfvarsFile -tfvarsFilePath $starterTfvarsPath -configuration $starterConfiguration

        # Caching the bootstrap and starter module values paths for retry / upgrade scenarios
        Write-ConfigurationCache -filePath $bootstrapCachePath -configuration $bootstrapConfiguration
        Write-ConfigurationCache -filePath $starterCachedPath -configuration $starterConfiguration

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