function New-Bootstrap {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $bootstrapName,

        [Parameter(Mandatory = $false)]
        [string] $userInputOverridePath = "",

        [Parameter(Mandatory = $false)]
        [string] $bootstrapFolderPath,

        [Parameter(Mandatory = $false)]
        [string] $starterFolderPath,

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

        # Setup Cache Paths
        $bootstrapCacheFileName = "cache-bootstrap-$bootstrapName.json"
        $starterCacheFileNamePattern = "cache-starter-*.json"

        # Run upgrade
        Invoke-Upgrade -alzEnvironmentDestination $alzEnvironmentDestination -bootstrapCacheFileName $bootstrapCacheFileName -starterCacheFileNamePattern $starterCacheFileNamePattern -stateFilePathAndFileName "bootstrap/$alzCicdPlatform/terraform.tfstate" -currentVersion $releaseTag -autoApprove:$autoApprove.IsPresent

        # Getting the configuration for the initial bootstrap user input and validators
        $bootstrapConfigFilePath = Join-Path -Path $bootstrapFolderPath -ChildPath ".config/ALZ-Powershell.config.json"
        $bootstrapConfig = Get-ALZConfig -configFilePath $bootstrapConfigFilePath

        # Getting additional configuration for the bootstrap module user input
        $bootstrapPath = Join-Path -Path $bootstrapFolderPath -ChildPath $bootstrapName
        $bootstrapVariableFilesPath = Join-Path -Path $bootstrapPath -ChildPath "variables.tf"
        $hclParserToolPath = Get-HCLParserTool -alzEnvironmentDestination $bootstrapPath -toolVersion "v0.6.0"
        $bootstrapParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $bootstrapVariableFilesPath -hclParserToolPath $hclParserToolPath -validators $bootstrapConfig.validators

        Write-InformationColored "Got configuration" -ForegroundColor Green -InformationAction Continue

        # Checking for cached bootstrap values for retry / upgrade scenarios
        $bootstrapCachedValuesPath = Join-Path -Path $bootstrapPath -ChildPath $bootstrapCacheFileName
        $cachedBootstrapConfig = Get-ALZConfig -configFilePath $bootstrapCachedValuesPath

        # Getting the user input for the bootstrap module
        $bootstrapConfiguration = Request-ALZEnvironmentConfig -configurationParameters $bootstrapParameters -respectOrdering -userInputOverrides $userInputOverrides -userInputDefaultOverrides $cachedBootstrapConfig -treatEmptyDefaultAsValid $true -autoApprove:$autoApprove.IsPresent

        # Getting the configuration for the starter module user input
        $starterTemplate = $bootstrapConfiguration.PsObject.Properties["starter_module"].Value.Value
        $starterTemplatePath = Join-Path -Path $starterFolderPath -ChildPath $starterTemplate
        $targetVariableFilePath = Join-Path -Path $starterTemplatePath -ChildPath "variables.tf"
        $starterModuleParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $targetVariableFilePath -hclParserToolPath $hclParserToolPath -validators $bootstrapConfig.validators

        Write-InformationColored "The following inputs are specific to the '$starterTemplate' starter module that you selected..." -ForegroundColor Green -InformationAction Continue

        # Checking for cached starter module values for retry / upgrade scenarios
        $starterCacheFileName = "cache-starter-$starterTemplate.json"
        $starterModuleCachedValuesPath = Join-Path -Path $starterFolderPath -ChildPath $starterCacheFileName
        $cachedStarterModuleConfig = Get-ALZConfig -configFilePath $starterModuleCachedValuesPath

        # Getting the user input for the starter module
        $starterModuleConfiguration = Request-ALZEnvironmentConfig -configurationParameters $starterModuleParameters -respectOrdering -userInputOverrides $userInputOverrides -userInputDefaultOverrides $cachedStarterModuleConfig -treatEmptyDefaultAsValid $true -autoApprove:$autoApprove.IsPresent

        # Getting computed inputs
        $starterPipelinePath = Join-Path -Path $starterFolderPath -ChildPath $starterPipelineFolder

        Import-StarterPath -bootstrapConfiguration $bootstrapConfiguration -starterPath starterTemplatePath -starterPipelinePath $starterPipelinePath
        Import-SubscriptionData -starterModuleConfiguration $starterModuleConfiguration -bootstrapConfiguration $bootstrapConfiguration
        Import-ConfigurationFileData -starterModuleConfiguration $starterModuleConfiguration -bootstrapConfiguration $bootstrapConfiguration

        # Creating the tfvars files for the bootstrap and starter module
        $bootstrapTfvarsPath = Join-Path -Path $bootstrapPath -ChildPath "override.tfvars"
        $starterModuleTfvarsPath = Join-Path -Path $starterTemplatePath -ChildPath "terraform.tfvars"
        Write-TfvarsFile -tfvarsFilePath $bootstrapTfvarsPath -configuration $bootstrapConfiguration
        Write-TfvarsFile -tfvarsFilePath $starterModuleTfvarsPath -configuration $starterModuleConfiguration

        # Caching the bootstrap and starter module values paths for retry / upgrade scenarios
        Write-ConfigurationCache -filePath $bootstrapCachedValuesPath -configuration $bootstrapConfiguration
        Write-ConfigurationCache -filePath $starterModuleCachedValuesPath -configuration $starterModuleConfiguration

        # Running terraform init and apply
        Write-InformationColored "Thank you for providing those inputs, we are now initializing and applying Terraform to bootstrap your environment..." -ForegroundColor Green -InformationAction Continue

        if($autoApprove) {
            Invoke-Terraform -moduleFolderPath $bootstrapPath -tfvarsFileName "override.tfvars" -autoApprove -destroy:$destroy.IsPresent
        } else {
            Write-InformationColored "Once the plan is complete you will be prompted to confirm the apply. You must enter 'yes' to apply." -ForegroundColor Green -InformationAction Continue
            Invoke-Terraform -moduleFolderPath $bootstrapPath -tfvarsFileName "override.tfvars" -destroy:$destroy.IsPresent
        }
    }
}