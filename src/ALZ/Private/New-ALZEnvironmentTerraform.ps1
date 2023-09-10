function New-ALZEnvironmentTerraform {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination,

        [Parameter(Mandatory = $false)]
        [string] $alzTerraformVersion,

        [Parameter(Mandatory = $false)]
        [ValidateSet("github", "azuredevops")]
        [Alias("Cicd")]
        [string] $alzCicdPlatform
    )

    $terraformModuleUrl = "https://github.com/Azure/alz-terraform-accelerator"

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {

        Write-InformationColored "Downloading alz-terraform-accelerator Terraform module to $alzEnvironmentDestination" -ForegroundColor Green -InformationAction Continue

        $release = Get-ALZGithubRelease -directoryForReleases $alzEnvironmentDestination -githubRepoUrl $terraformModuleUrl -releases $alzTerraformVersion | Out-String | Write-Verbose
        $terraformConfig = Get-ALZConfig -alzVersion $release -alzIacProvider "terraform"

        $configuration = Request-ALZEnvironmentConfig -configurationParameters $terraformConfig.parameters

        if($alzCicdPlatform -eq "github") {
            $configuration = $configuration | Where-Object { $_.Name -like "AzureDevOps" }
        }

        if($configuration.Length -gt 0) {
            Write-InformationColored "Creating ALZ-Terraform environment in $configuration" -ForegroundColor Green -InformationAction Continue
        }
    }
}