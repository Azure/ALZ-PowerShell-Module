function Get-AcceleratorConfigPath {
    <#
    .SYNOPSIS
    Builds the input configuration file paths and additional files based on IaC type.
    .DESCRIPTION
    This function generates the list of configuration file paths and additional files
    needed for the accelerator based on the IaC type (terraform, bicep, etc.).
    .PARAMETER ConfigFolderPath
    The path to the config folder containing the configuration files.
    .PARAMETER IacType
    The Infrastructure as Code type (terraform, bicep, or bicep-classic).
    .OUTPUTS
    Returns a hashtable with the following keys:
    - InputConfigFilePaths: Array of input configuration file paths
    - StarterAdditionalFiles: Array of additional files/folders for the starter module
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ConfigFolderPath,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [string] $IacType
    )

    $inputConfigFilePaths = @("$ConfigFolderPath/inputs.yaml")
    $starterAdditionalFiles = @()

    switch ($IacType) {
        "terraform" {
            $inputConfigFilePaths += "$ConfigFolderPath/platform-landing-zone.tfvars"
            $libFolderPath = "$ConfigFolderPath/lib"
            if (Test-Path $libFolderPath) {
                $starterAdditionalFiles = @($libFolderPath)
            }
        }
        "bicep" {
            $inputConfigFilePaths += "$ConfigFolderPath/platform-landing-zone.yaml"
        }
        # bicep-classic and others just use inputs.yaml
    }

    return @{
        InputConfigFilePaths   = $inputConfigFilePaths
        StarterAdditionalFiles = $starterAdditionalFiles
    }
}
