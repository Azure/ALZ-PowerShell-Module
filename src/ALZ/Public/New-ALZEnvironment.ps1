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
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment
    .EXAMPLE
    New-ALZEnvironment -alzEnvironmentDestination "."
    .EXAMPLE
    New-ALZEnvironment -alzEnvironmentDestination "." -alzBicepVersion "v0.13.0"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination = ".",

        [Parameter(Mandatory = $false)]
        [string] $alzBicepVersion = "v0.13.0",

        [Parameter(Mandatory = $false)]
        [ValidateSet("bicep", "terraform")]
        [Alias("Iac")]
        [string] $alzIacProvider = "bicep"
    )

    Write-InformationColored "Getting ready to create a new ALZ environment with you..." -ForegroundColor Green  -InformationAction Continue

    if ($alzIacProvider -eq "terraform") {
        Write-InformationColored "Terraform is not yet supported." -ForegroundColor Red  -InformationAction Continue
        return $false
    }

    $configuration = Request-ALZEnvironmentConfig -alzIacProvider $alzIacProvider

    if ($PSCmdlet.ShouldProcess("ALZ-Bicep module configuration", "modify")) {

        New-ALZDirectoryEnvironment -alzEnvironmentDestination $alzEnvironmentDestination | Out-Null

        $assetsDirectory = Join-Path $(Get-ScriptRoot) "../Assets"
        Copy-Item -Path "$assetsDirectory/*" -Recurse -Destination $alzEnvironmentDestination -Force

        if ($alzIacProvider -eq "bicep") {
            $alzEnvironmentDestinationInternalCode = Join-Path $alzEnvironmentDestination "alz-bicep-internal" $alzBicepVersion
            $alzBicepSourceDirectory = Get-ALZBicepSource -alzBicepVersion $alzBicepVersion
            Initialize-ALZBicepConfigFiles -alzEnvironmentDestination $alzEnvironmentDestination -alzBicepVersion $alzBicepVersion | Out-Null
        }

        Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination $alzEnvironmentDestination -configuration $configuration | Out-Null
    }

    return $true
}