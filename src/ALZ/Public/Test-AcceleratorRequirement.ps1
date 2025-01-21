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

    Test-Tooling
}
