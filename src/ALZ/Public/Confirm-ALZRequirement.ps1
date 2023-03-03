<#
.SYNOPSIS
    Check that the ALZ software requirements are met
.DESCRIPTION
    This will chack if you have all the required software needed to use this module.
    It will check for the following software:
    - PowerShell 7.1 or higher
    - Git
    - Azure PowerShell module

.EXAMPLE
    C:\PS> Confirm-ALZRequirements
.EXAMPLE
    C:\PS> Confirm-ALZRequirements -Verbose
.PARAMETER InputObject
    Specifies the object to be processed.  You can also pipe the objects to this command.
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
.COMPONENT
    ALZ
#>
function Confirm-ALZRequirement {
    [CmdletBinding()]
    param (
    )

    # Check if PowerShell is the corrrect version
    $psVersion = $PSVersionTable.PSVersion
    $psMajorVersion = $psVersion.Major
    $psMinorVersion = $psVersion.Minor
    if ($psMajorVersion -lt 7) {
        Write-Error "PowerShell version $psMajorVersion.$psMinorVersion is not supported. Please upgrade to PowerShell 7.1 or higher."
    } elseif ($psMajorVersion -eq 7 -and $psMinorVersion -lt 1) {
        Write-Error "PowerShell version $psMajorVersion.$psMinorVersion is not supported. Please upgrade to PowerShell 7.1 or higher."
    } else {
        Write-Verbose "PowerShell version $psMajorVersion.$psMinorVersion is supported."
    }

    # Check if Git is installed
    $gitPath = Get-Command git -ErrorAction SilentlyContinue
    if ($gitPath) {
        Write-Verbose "Git is installed."
    } else {
        Write-Error "Git is not installed. Please install Git."
    }

    # Check if Azure PowerShell module is installed
    $azModule = Get-Module -Name Az -ListAvailable
    if ($azModule) {
        Write-Verbose "Azure PowerShell module is installed."
    } else {
        Write-Error "Azure PowerShell module is not installed. Please install the Azure PowerShell module."
    }
    return "ALZ requirements are met."
}

