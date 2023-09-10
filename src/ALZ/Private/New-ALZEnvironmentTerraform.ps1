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

        $releaseObject = Get-ALZGithubRelease -directoryForReleases $alzEnvironmentDestination -githubRepoUrl $terraformModuleUrl -releases $alzVersion
        $release = $($releaseObject.name)

        Write-InformationColored "Downloaded alz-terraform-accelerator Terraform module version $release to $alzEnvironmentDestination" -ForegroundColor Green -InformationAction Continue

        $terraformConfig = Get-ALZConfig -alzVersion $release -alzIacProvider "terraform"

        $configuration = Request-ALZEnvironmentConfig -configurationParameters $terraformConfig.parameters

        Write-InformationColored "$alzCicdPlatform $($configuration.PsObject.Properties)" -ForegroundColor Green -InformationAction Continue
    }
}