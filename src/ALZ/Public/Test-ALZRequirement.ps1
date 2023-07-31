function Test-ALZRequirement {
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
    .OUTPUTS
        Boolean - True if all requirements are met, false if not.
    .NOTES
        This function is used by the ALZ build script to ensure that the software requirements are met before attempting to
        build the ALZ environment.
    .COMPONENT
        ALZ
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("bicep", "terraform")]
        [Alias("Iac")]
        [string] $alzIacProvider = "bicep"
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

    if ($alzIacProvider -eq "terraform") {
        # Check if Terraform is installed
        $terraformPath = Get-Command terraform -ErrorAction SilentlyContinue
        if ($terraformPath) {
            Write-Verbose "Terraform is installed."
        } else {
            Write-Error "Terraform is not installed. Please install Terraform."
            $result = $false
        }
        # Check if Azure CLI is installed
        $azCliPath = Get-Command az -ErrorAction SilentlyContinue
        if ($azCliPath) {
            Write-Verbose "Azure CLI is installed."
        } else {
            Write-Error "Azure CLI is not installed. Please install Azure CLI."
            $result = $false
        }
    }

    if ($alzIacProvider -eq "bicep") {
        # Check if Bicep is installed
        $bicepPath = Get-Command bicep -ErrorAction SilentlyContinue
        if ($bicepPath) {
            Write-Verbose "Bicep is installed."
        } else {
            Write-Error "Bicep is not installed. Please install Bicep."
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
}



