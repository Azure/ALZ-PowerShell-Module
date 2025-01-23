function Test-AcceleratorRequirement {
    <#
    .SYNOPSIS
        Test that the Accelerator software requirements are met
    .DESCRIPTION
        This will check for the pre-requisite software
    .EXAMPLE
        C:\PS> Test-AcceleratorRequirement
    .EXAMPLE
        C:\PS> Test-AcceleratorRequirement -Verbose
    .OUTPUTS
        Boolean - True if all requirements are met, false if not.
    .NOTES
        This function is used by the Deploy-Accelerator function to ensure that the software requirements are met before attempting run the Accelerator.
    .COMPONENT
        ALZ
    #>
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Determines whether to skip the requirements check for the ALZ PowerShell Module version only. This is not recommended."
        )]
        [Alias("skipAlzModuleVersionRequirementsCheck")]
        [switch] $skip_alz_module_version_requirements_check
    )
    Test-Tooling -skipAlzModuleVersionCheck:$skip_alz_module_version_requirements_check.IsPresent
}
