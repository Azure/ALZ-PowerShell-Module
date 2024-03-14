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
        [Alias("i")]
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

    if ($alzIacProvider -eq "terraform") {
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
        # Check if Git is installed
        $gitPath = Get-Command git -ErrorAction SilentlyContinue
        if ($gitPath) {
            Write-Verbose "Git is installed."
        } else {
            Write-Error "Git is not installed. Please install Git."
            $result = $false
        }

        # Check if VS Code is installed
        $vsCodePath = Get-Command code -ErrorAction SilentlyContinue
        if ($vsCodePath) {
            Write-Verbose "Visual Studio Code is installed."
        } else {
            Write-Error "Visual Studio Code is not installed. Please install Visual Studio Code."
            $result = $false
        }
        # Check if Bicep is installed
        $bicepPath = Get-Command bicep -ErrorAction SilentlyContinue
        if ($bicepPath) {
            Write-Verbose "Bicep is installed."
        } else {
            Write-Error "Bicep is not installed. Please install Bicep."
            $result = $false
        }
        # Check if AZ PowerShell module is the correct version
        $azModule = Get-AZVersion
        if ($azModule.Version.Major -lt 10) {
            Write-Error "Az module version $($azModule.Version) is not supported. Please Upgrade to AZ module version 10.0.0 or higher."
            $result = $false
        } else {
            Write-Verbose "Az module version is supported."
        }
    }
    if ($result) {
        return "ALZ requirements are met."
    } else {
        return "ALZ requirements are not met."
    }
}



