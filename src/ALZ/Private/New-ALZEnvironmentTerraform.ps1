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

        $releaseObject = Get-ALZGithubRelease -directoryForReleases $alzEnvironmentDestination -githubRepoUrl $terraformModuleUrl -releases $alzVersion -queryOnly
        $release = $($releaseObject.name)
        $bootstrapConfig = Get-ALZConfig -alzVersion $release -alzIacProvider "terraform"
        $releaseObject = Get-ALZGithubRelease -directoryForReleases $alzEnvironmentDestination -githubRepoUrl $terraformModuleUrl -releases $release

        $releasePath = Join-Path -Path $alzEnvironmentDestination -ChildPath $release

        $bootstrapParameters = $bootstrapConfig.parameters

        if($alzCicdPlatform -eq "github") {
            $bootstrapParameters = Select-Object -InputObject $bootstrapParameters -Property * -ExcludeProperty "azure_devops_*"
        }

        Write-InformationColored "Got configuration and downloaded alz-terraform-accelerator Terraform module version $release to $alzEnvironmentDestination" -ForegroundColor Green -InformationAction Continue

        $bootstrapConfiguration = Request-ALZEnvironmentConfig -configurationParameters $bootstrapParameters
        $starterTemplate = $bootstrapConfiguration.PsObject.Properties["starter_module"].Value.Value
        $starterTemplatePath = Join-Path -Path $releasePath -ChildPath "templates/$($starterTemplate)"

        $hclParserToolPath = Get-HCLParserTool -alzEnvironmentDestination $releasePath -toolVersion "v0.6.0"

        $targetVariableFile = Join-Path -Path $starterTemplatePath -ChildPath "variables.tf"
        $starterModuleParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $targetVariableFile -hclParserToolPath $hclParserToolPath
        Write-InformationColored "The following inputs are specific to the '$starterTemplate' starter module that you selected..." -ForegroundColor Green -InformationAction Continue
        $starterModuleConfiguration = Request-ALZEnvironmentConfig -configurationParameters $starterModuleParameters

        $bootstrapPath = Join-Path -Path $releasePath -ChildPath "bootstrap/$alzCicdPlatform"

        $bootstrapTfvarsPath = Join-Path -Path $bootstrapPath -ChildPath "override.tfvars"
        $starterModuleTfvarsPath = Join-Path -Path $starterTemplatePath -ChildPath "terraform.tfvars"

        Write-TfvarsFile -tfvarsFilePath $bootstrapTfvarsPath -configuration $bootstrapConfiguration
        Write-TfvarsFile -tfvarsFilePath $starterModuleTfvarsPath -configuration $starterModuleConfiguration

        Invoke-Terraform -moduleFolderPath $bootstrapPath -tfvarsFileName "override.tfvars"
    }
}