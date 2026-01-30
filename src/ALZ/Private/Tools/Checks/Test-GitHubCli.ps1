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
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $results += @{
                message = "GitHub CLI is authenticated."
                result  = "Success"
            }

            # Check if admin:org scope is available
            Write-Verbose "Checking GitHub CLI scopes for admin:org"
            if ($authStatus -match "admin:org") {
                $results += @{
                    message = "GitHub CLI has admin:org scope."
                    result  = "Success"
                }
            } else {
                Write-ToConsoleLog "GitHub CLI is missing admin:org scope. Requesting scope refresh..." -IsWarning
                # Prompt user to add the admin:org scope
                gh auth refresh -h github.com -s admin:org
                if ($LASTEXITCODE -eq 0) {
                    $results += @{
                        message = "GitHub CLI admin:org scope added successfully."
                        result  = "Success"
                    }
                } else {
                    $results += @{
                        message = "Failed to add admin:org scope. Please run 'gh auth refresh -h github.com -s admin:org' manually."
                        result  = "Failure"
                    }
                    $hasFailure = $true
                }
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
