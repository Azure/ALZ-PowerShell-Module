function Test-GitInstallation {
    [CmdletBinding()]
    param()

    $results = @()
    $hasFailure = $false

    Write-ToConsoleLog "Checking Git installation..."
    Write-Verbose "Checking Git installation"
    $gitPath = Get-Command git -ErrorAction SilentlyContinue

    if ($gitPath) {
        $results += @{
            message = "Git is installed."
            result  = "Success"
        }
    } else {
        $results += @{
            message = "Git is not installed. Follow the instructions here: https://git-scm.com/downloads"
            result  = "Failure"
        }
        $hasFailure = $true
    }

    return @{
        Results    = $results
        HasFailure = $hasFailure
    }
}
