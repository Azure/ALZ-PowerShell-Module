function Test-PowerShellVersion {
    [CmdletBinding()]
    param()

    $results = @()
    $hasFailure = $false

    Write-Verbose "Checking PowerShell version"
    $powerShellVersionTable = $PSVersionTable
    $powerShellVersion = $powerShellVersionTable.PSVersion.ToString()

    if ($powerShellVersionTable.PSVersion.Major -lt 7) {
        $results += @{
            message = "PowerShell version $powerShellVersion is not supported. Please upgrade to PowerShell 7.4 or higher. Either switch to the ``pwsh`` prompt or follow the instructions here: https://aka.ms/install-powershell"
            result  = "Failure"
        }
        $hasFailure = $true
    } elseif ($powerShellVersionTable.PSVersion.Major -eq 7 -and $powerShellVersionTable.PSVersion.Minor -lt 4) {
        $results += @{
            message = "PowerShell version $powerShellVersion is not supported. Please upgrade to PowerShell 7.4 or higher. Either switch to the ``pwsh`` prompt or follow the instructions here: https://aka.ms/install-powershell"
            result  = "Failure"
        }
        $hasFailure = $true
    } else {
        $results += @{
            message = "PowerShell version $powerShellVersion is supported."
            result  = "Success"
        }
    }

    return @{
        Results    = $results
        HasFailure = $hasFailure
    }
}
