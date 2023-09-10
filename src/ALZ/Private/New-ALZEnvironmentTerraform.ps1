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
        $terraformConfig = Get-ALZConfig -alzVersion $release -alzIacProvider "terraform"
        $releaseObject = Get-ALZGithubRelease -directoryForReleases $alzEnvironmentDestination -githubRepoUrl $terraformModuleUrl -releases $release

        $releasePath = Join-Path -Path $alzEnvironmentDestination -ChildPath $release

        Write-InformationColored "Got configuration and downloaded alz-terraform-accelerator Terraform module version $release to $alzEnvironmentDestination" -ForegroundColor Green -InformationAction Continue

        $configuration = Request-ALZEnvironmentConfig -configurationParameters $terraformConfig.parameters

        $hclParserToolPath = Get-HCLParserTool -alzEnvironmentDestination $releasePath -toolVersion "v0.6.0"
        $starterTemplate = $configuration.PsObject.Properties["StarterModule"].Value.Value
        $targetVariableFile = Join-Path -Path $releasePath -ChildPath "templates/$($starterTemplate)/variables.tf"
        $starterModuleParameters = Convert-HCLVariablesToUserInputConfig -targetVariableFile $targetVariableFile -hclParserToolPath $hclParserToolPath
        Write-InformationColored "The following inputs are specific to the '$startTemplate' starter module that you selected..." -ForegroundColor Green -InformationAction Continue
        $starterModuleConfiguration = Request-ALZEnvironmentConfig -configurationParameters $starterModuleParameters

        Write-InformationColored $starterModuleConfiguration.PSObject.Properties -ForegroundColor Green -InformationAction Continue
        Write-InformationColored "----$alzCicdPlatform $($configuration.GetType()) $($starterModuleConfiguration.GetType())----" -ForegroundColor Green -InformationAction Continue
        Write-InformationColored $configuration.PsObject.Properties -ForegroundColor Green -InformationAction Continue
    }
}