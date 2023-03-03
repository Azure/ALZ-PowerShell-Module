<#
.SYNOPSIS
    Test that the ALZ software requirements are met
.DESCRIPTION
    This will check for the following software:
    - PowerShell 7.1 or higher
    - Git
    - Azure PowerShell module

.EXAMPLE
    C:\PS> Test-ALZRequirements
.EXAMPLE
    C:\PS> Test-ALZRequirements -Verbose
.PARAMETER InputObject
    Specifies the object to be processed.  You can also pipe the objects to this command.
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
.COMPONENT
    ALZ
#>

# Used to allow mocking of the $PSVersionTable variable
function Get-PSVersion { $PSVersionTable }


function Test-ALZRequirement {
    [CmdletBinding()]
    param (
    )

    $result = $true
    # Check if PowerShell is the corrrect version
    if ((Get-PSVersion).PSVersion.Major -lt 7) {
        Write-Error "PowerShell version $psMajorVersion.$psMinorVersion is not supported. Please upgrade to PowerShell 7.1 or higher."
        $result = $false
    } elseif ((Get-PSVersion).PSVersion.Major -eq 7 -and (Get-PSVersion).PSVersion.Minor -lt 1) {
        Write-Error "PowerShell version $psMajorVersion.$psMinorVersion is not supported. Please upgrade to PowerShell 7.1 or higher."
        $result = $false
    } else {
        Write-Verbose "PowerShell version $psMajorVersion.$psMinorVersion is supported."
    }

    # Check if Git is installed
    $gitPath = Get-Command git -ErrorAction SilentlyContinue
    if ($gitPath) {
        Write-Verbose "Git is installed."
    } else {
        Write-Error "Git is not installed. Please install Git."
        $result = $false
    }

    # Check if Azure PowerShell module is installed
    $azModule = Get-Module -Name Az -ListAvailable
    if ($azModule) {
        Write-Verbose "Azure PowerShell module is installed."
    } else {
        Write-Error "Azure PowerShell module is not installed. Please install the Azure PowerShell module."
        $result = $false
    }
    if ($result) {
        return "ALZ requirements are met."
    } else {
        return "ALZ requirements are not met."
    }
}

