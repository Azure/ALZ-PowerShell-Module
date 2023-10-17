function New-ALZEnvironmentTerraform {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination,

        [Parameter(Mandatory = $false)]
        [string] $alzVersion,

        [Parameter(Mandatory = $false)]
        [ValidateSet("github", "azuredevops")]
        [Alias("Cicd")]
        [string] $alzCicdPlatform,

        [Parameter(Mandatory = $false)]
        [Alias("inputs")]
        [string] $userInputOverridePath = "",

        [Parameter(Mandatory = $false)]
        [switch] $autoApprove
    )

    $terraformModuleUrl = "https://github.com/Azure/alz-terraform-accelerator"

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {

        Write-InformationColored "Downloading alz-terraform-accelerator Terraform module to $alzEnvironmentDestination" -ForegroundColor Green -InformationAction Continue

        # Get User Input Overrides (used for automated testing purposes and advanced use cases)
        $userInputOverrides = $null
        if($userInputOverridePath -ne "") {
            $userInputOverrides = Get-ALZConfig -configFilePath $userInputOverridePath
        }

        # Downloading the latest or specified version of the alz-terraform-accelerator module
        $releaseTag = Get-ALZGithubRelease -directoryForReleases $alzEnvironmentDestination -githubRepoUrl $terraformModuleUrl -release $alzVersion
        $releasePath = Join-Path -Path $alzEnvironmentDestination -ChildPath $releaseTag

        # Getting the configuration for the initial bootstrap user input and validators
        $bootstrapConfigFilePath = Join-Path -Path $releasePath -ChildPath "bootstrap/.config/ALZ-Powershell.config.json"
        $bootstrapConfig = Get-ALZConfig -configFilePath $bootstrapConfigFilePath

        # Getting additional configuration for the bootstrap module user input
        $bootstrapPath = Join-Path -Path $releasePath -ChildPath "bootstrap/$alzCicdPlatform"
        $bootstrapVariableFilesPath = Join-Path -Path $bootstrapPath -ChildPath "variables.tf"
        $hclParserToolPath = Get-HCLParserTool -alzEnvironmentDestination $releasePath -toolVersion "v0.6.0"
        $bootstrapParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $bootstrapVariableFilesPath -hclParserToolPath $hclParserToolPath -validators $bootstrapConfig.validators

        Write-InformationColored "Got configuration and downloaded alz-terraform-accelerator Terraform module version $releaseTag to $alzEnvironmentDestination" -ForegroundColor Green -InformationAction Continue

        # Getting the user input for the bootstrap module
        $bootstrapConfiguration = Request-ALZEnvironmentConfig -configurationParameters $bootstrapParameters -respectOrdering -userInputOverrides $userInputOverrides -treatEmptyDefaultAsValid $true

        # Getting the configuration for the starter module user input
        $starterTemplate = $bootstrapConfiguration.PsObject.Properties["starter_module"].Value.Value
        $starterTemplatePath = Join-Path -Path $releasePath -ChildPath "templates/$($starterTemplate)"
        $targetVariableFilePath = Join-Path -Path $starterTemplatePath -ChildPath "variables.tf"
        $starterModuleParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $targetVariableFilePath -hclParserToolPath $hclParserToolPath -validators $bootstrapConfig.validators

        Write-InformationColored "The following inputs are specific to the '$starterTemplate' starter module that you selected..." -ForegroundColor Green -InformationAction Continue

        # Getting the user input for the starter module
        $starterModuleConfiguration = Request-ALZEnvironmentConfig -configurationParameters $starterModuleParameters -respectOrdering -userInputOverrides $userInputOverrides -treatEmptyDefaultAsValid $true

        # Getting subscription ids
        Import-SubscriptionData -starterModuleConfiguration $starterModuleConfiguration -bootstrapConfiguration $bootstrapConfiguration

        # Creating the tfvars files for the bootstrap and starter module
        $bootstrapTfvarsPath = Join-Path -Path $bootstrapPath -ChildPath "override.tfvars"
        $starterModuleTfvarsPath = Join-Path -Path $starterTemplatePath -ChildPath "terraform.tfvars"
        Write-TfvarsFile -tfvarsFilePath $bootstrapTfvarsPath -configuration $bootstrapConfiguration
        Write-TfvarsFile -tfvarsFilePath $starterModuleTfvarsPath -configuration $starterModuleConfiguration

        # Running terraform init and apply
        Write-InformationColored "Thank you for providing those inputs, we are now initializing and applying Terraform to bootstrap your environment..." -ForegroundColor Green -InformationAction Continue

        if($autoApprove) {
            Invoke-Terraform -moduleFolderPath $bootstrapPath -tfvarsFileName "override.tfvars" -autoApprove
        } else {
            Write-InformationColored "Once the plan is complete you will be prompted to confirm the apply. You must enter 'yes' to apply." -ForegroundColor Green -InformationAction Continue
            Invoke-Terraform -moduleFolderPath $bootstrapPath -tfvarsFileName "override.tfvars"
        }
    }
}