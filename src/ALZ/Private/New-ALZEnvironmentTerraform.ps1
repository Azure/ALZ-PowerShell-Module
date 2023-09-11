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
        [string] $alzCicdPlatform
    )

    $terraformModuleUrl = "https://github.com/Azure/alz-terraform-accelerator"

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {

        Write-InformationColored "Downloading alz-terraform-accelerator Terraform module to $alzEnvironmentDestination" -ForegroundColor Green -InformationAction Continue

        # Downloading the latest or specified version of the alz-terraform-accelerator module
        $releaseObject = Get-ALZGithubRelease -directoryForReleases $alzEnvironmentDestination -githubRepoUrl $terraformModuleUrl -releases $alzVersion
        $release = $($releaseObject.name)
        $releasePath = Join-Path -Path $alzEnvironmentDestination -ChildPath $release

        # Getting the configuration for the bootstrap user input
        $bootstrapConfigFilePath = Join-Path -Path $releasePath -ChildPath "bootstrap/.config/ALZ-Powershell.config.json"
        $bootstrapConfig = Get-ALZConfig -configFilePath $bootstrapConfigFilePath
        $bootstrapParameters = $bootstrapConfig.parameters

        if($alzCicdPlatform -eq "github") {
            $bootstrapParameters = Select-Object -InputObject $bootstrapParameters -Property * -ExcludeProperty "azure_devops_*"
        }

        Write-InformationColored "Got configuration and downloaded alz-terraform-accelerator Terraform module version $release to $alzEnvironmentDestination" -ForegroundColor Green -InformationAction Continue

        # Getting the user input for the bootstrap module
        $bootstrapConfiguration = Request-ALZEnvironmentConfig -configurationParameters $bootstrapParameters

        # Getting the configuration for the starter module user input
        $starterTemplate = $bootstrapConfiguration.PsObject.Properties["starter_module"].Value.Value
        $starterTemplatePath = Join-Path -Path $releasePath -ChildPath "templates/$($starterTemplate)"
        $hclParserToolPath = Get-HCLParserTool -alzEnvironmentDestination $releasePath -toolVersion "v0.6.0"
        $targetVariableFilePath = Join-Path -Path $starterTemplatePath -ChildPath "variables.tf"
        $starterModuleParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $targetVariableFilePath -hclParserToolPath $hclParserToolPath -validators $bootstrapConfig.validators

        Write-InformationColored "The following inputs are specific to the '$starterTemplate' starter module that you selected..." -ForegroundColor Green -InformationAction Continue

        # Getting the user input for the starter module
        $starterModuleConfiguration = Request-ALZEnvironmentConfig -configurationParameters $starterModuleParameters

        # Creating the tfvars files for the bootstrap and starter module
        $bootstrapPath = Join-Path -Path $releasePath -ChildPath "bootstrap/$alzCicdPlatform"
        $bootstrapTfvarsPath = Join-Path -Path $bootstrapPath -ChildPath "override.tfvars"
        $starterModuleTfvarsPath = Join-Path -Path $starterTemplatePath -ChildPath "terraform.tfvars"
        Write-TfvarsFile -tfvarsFilePath $bootstrapTfvarsPath -configuration $bootstrapConfiguration
        Write-TfvarsFile -tfvarsFilePath $starterModuleTfvarsPath -configuration $starterModuleConfiguration

        # Running terraform init and apply
        Invoke-Terraform -moduleFolderPath $bootstrapPath -tfvarsFileName "override.tfvars"
    }
}