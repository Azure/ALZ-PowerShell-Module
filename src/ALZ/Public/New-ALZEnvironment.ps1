function New-ALZEnvironment {
    <#
    .SYNOPSIS
    This function prompts a user for configuration values and modifies the ALZ Bicep configuration files accordingly.
    .DESCRIPTION
    This function will prompt the user for commonly used deployment configuration settings and modify the configuration in place.
    .PARAMETER alzBicepSource
    The directory containing the ALZ-Bicep source repo.
    .PARAMETER alzEnvironmentDestination
    The directory where the ALZ environment will be created.
    .PARAMETER alzBicepVersion
    The version of the ALZ-Bicep module to use.
    .PARAMETER alzIacProvider
    The IaC provider to use for the ALZ environment.
    .PARAMETER userInputOverridePath
    A json file containing user input overrides for the user input prompts. This will cause the tool to by pass requesting user input for that field and use the value(s) provided. E.g { "starter_module": "basic", "azure_location": "uksouth" }
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment -alzEnvironmentDestination "."
    .EXAMPLE
    New-ALZEnvironment -alzEnvironmentDestination "." -alzBicepVersion "v0.16.3"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination = ".",

        [Parameter(Mandatory = $false)]
        [Alias("alzBicepVersion")]
        [string] $alzVersion = "",

        [Parameter(Mandatory = $false)]
        [ValidateSet("bicep", "terraform")]
        [Alias("Iac")]
        [string] $alzIacProvider = "bicep",

        [Parameter(Mandatory = $false)]
        [ValidateSet("github", "azuredevops")]
        [Alias("Cicd")]
        [string] $alzCicdPlatform = "github",

        [Parameter(Mandatory = $false)]
        [Alias("inputs")]
        [string] $userInputOverridePath = ""
    )

    Write-InformationColored "Getting ready to create a new ALZ environment with you..." -ForegroundColor Green -InformationAction Continue

    if ($PSCmdlet.ShouldProcess("Accelerator setup", "modify")) {
        switch($alzIacProvider) {
            "bicep" {
                if($alzVersion -eq "") {
                    $alzVersion = "v0.16.3"
                }
                New-ALZEnvironmentBicep -alzEnvironmentDestination $alzEnvironmentDestination -alzVersion $alzVersion -alzCicdPlatform $alzCicdPlatform
            }
            "terraform" {
                if($alzVersion -eq "") {
                    $alzVersion = "latest"
                }
                New-ALZEnvironmentTerraform -alzEnvironmentDestination $alzEnvironmentDestination -alzVersion $alzVersion -alzCicdPlatform $alzCicdPlatform -userInputOverridePath $userInputOverridePath
            }
        }
    }

    return
}