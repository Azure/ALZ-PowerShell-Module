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

        Write-InformationColored "Got configuration and downloaded alz-terraform-accelerator Terraform module version $release to $alzEnvironmentDestination" -ForegroundColor Green -InformationAction Continue

        $configuration = Request-ALZEnvironmentConfig -configurationParameters $terraformConfig.parameters

        $os = ""
        if ($IsWindows) {
            $os = "windows"
        }
        if($IsLinux){
            $os = "linux"
        }
        if($IsMacOS){
            $os = "darwin"
        }

        $architecture = $($env:PROCESSOR_ARCHITECTURE).ToLower()
        $download = "hcl2json_$($os)_$($architecture)"

        if($os -eq "windows") {
            $download = "$($download).exe"
        }

        if(!(Test-Path $download)) {
            Invoke-WebRequest -Uri "https://github.com/tmccombs/hcl2json/releases/download/v0.6.0/$($download)" -OutFile "$download" | Out-String | Write-Verbose
        }

        $starterTemplate = "basic"
        $targetVariableFile = "./$($release)/templates/$($starterTemplate)/variables.tf"
        $terraformVariables = & "./$download" $targetVariableFile | ConvertFrom-Json

        $starterModuleConfiguration = [PSCustomObject]@{}

        foreach($variable in $terraformVariables.variable.PSObject.Properties) {
            Write-InformationColored $variable -ForegroundColor Green -InformationAction Continue
            Write-InformationColored $variable.Name -ForegroundColor Green -InformationAction Continue
            $starterModuleConfigurationInstance = [PSCustomObject]@{}
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Type" -NotePropertyValue "UserInput"
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Description" -NotePropertyValue $variable.Value[0].description
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Value" -NotePropertyValue ""
            $starterModuleConfiguration | Add-Member -MemberType AliasProperty -Name $variable.Name -Value $starterModuleConfigurationInstance
        }

        Write-InformationColored $starterModuleConfiguration.PSObject.Properties -ForegroundColor Green -InformationAction Continue

        Write-InformationColored "$alzCicdPlatform $($configuration.PsObject.Properties)" -ForegroundColor Green -InformationAction Continue
    }
}