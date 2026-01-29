function Test-GitHubCli {
    [CmdletBinding()]
    param()

    $results = @()
    $hasFailure = $false

    Write-Verbose "Checking GitHub CLI installation"
    $ghCliPath = Get-Command gh -ErrorAction SilentlyContinue

    if ($ghCliPath) {
        $results += @{
            message = "GitHub CLI is installed."
            result  = "Success"
        }

        # Check if GitHub CLI is authenticated
        Write-Verbose "Checking GitHub CLI authentication status"
        $null = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $results += @{
                message = "GitHub CLI is authenticated."
                result  = "Success"
            }
        } else {
            $results += @{
                message = "GitHub CLI is not authenticated. Please authenticate using 'gh auth login'."
                result  = "Failure"
            }
            $hasFailure = $true
        }
    } else {
        $results += @{
            message = "GitHub CLI is not installed. Follow the instructions here: https://cli.github.com/"
            result  = "Failure"
        }
        $hasFailure = $true
    }

    return @{
        Results    = $results
        HasFailure = $hasFailure
    }
}
