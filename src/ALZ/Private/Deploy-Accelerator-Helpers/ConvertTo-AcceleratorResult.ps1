function ConvertTo-AcceleratorResult {
    <#
    .SYNOPSIS
    Creates a standardized result hashtable for accelerator configuration functions.
    .DESCRIPTION
    This function creates a consistent result structure used by accelerator configuration
    functions to return their status and configuration data.
    .PARAMETER Continue
    Boolean indicating whether to continue with deployment.
    .PARAMETER InputConfigFilePaths
    Array of input configuration file paths.
    .PARAMETER StarterAdditionalFiles
    Array of additional files/folders for the starter module.
    .PARAMETER OutputFolderPath
    Path to the output folder.
    .OUTPUTS
    Returns a hashtable with Continue, InputConfigFilePaths, StarterAdditionalFiles, and OutputFolderPath keys.
    .EXAMPLE
    return ConvertTo-AcceleratorResult -Continue $false
    .EXAMPLE
    return ConvertTo-AcceleratorResult -Continue $true -InputConfigFilePaths @("config/inputs.yaml") -OutputFolderPath "~/accelerator/output"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool] $Continue,

        [Parameter(Mandatory = $false)]
        [array] $InputConfigFilePaths = @(),

        [Parameter(Mandatory = $false)]
        [array] $StarterAdditionalFiles = @(),

        [Parameter(Mandatory = $false)]
        [string] $OutputFolderPath = ""
    )

    return @{
        Continue               = $Continue
        InputConfigFilePaths   = $InputConfigFilePaths
        StarterAdditionalFiles = $StarterAdditionalFiles
        OutputFolderPath       = $OutputFolderPath
    }
}
