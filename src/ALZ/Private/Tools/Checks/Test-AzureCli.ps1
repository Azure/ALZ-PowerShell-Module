function Test-AzureCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$RequireLogin = $true
    )

    $results = @()
    $hasFailure = $false
    $azCliInstalledButNotLoggedIn = $false

    # Check if Azure CLI is installed
    Write-Verbose "Checking Azure CLI installation"
    $azCliPath = Get-Command az -ErrorAction SilentlyContinue
    if ($azCliPath) {
        $results += @{
            message = "Azure CLI is installed."
            result  = "Success"
        }

        # Check if Azure CLI is logged in
        Write-Verbose "Checking Azure CLI login status"
        $azCliAccount = $(az account show -o json 2>$null) | ConvertFrom-Json
        if ($azCliAccount) {
            $results += @{
                message = "Azure CLI is logged in. Tenant ID: $($azCliAccount.tenantId), Subscription: $($azCliAccount.name) ($($azCliAccount.id))"
                result  = "Success"
            }

            # Verify access token can be obtained/refreshed
            Write-Verbose "Checking Azure CLI access token"
            $tokenResult = $(az account get-access-token -o json 2>$null) | ConvertFrom-Json
            if ($tokenResult -and $tokenResult.accessToken) {
                $results += @{
                    message = "Azure CLI access token is valid."
                    result  = "Success"
                }
            } else {
                $results += @{
                    message = "Azure CLI access token could not be obtained. Please re-authenticate using 'az login -t `"$($azCliAccount.tenantId)`"'."
                    result  = "Failure"
                }
                $hasFailure = $true
            }
        } else {
            $azCliInstalledButNotLoggedIn = $true
            if (-not $RequireLogin) {
                $results += @{
                    message = "Azure CLI is not logged in. Login will be prompted later."
                    result  = "Warning"
                }
            } else {
                $results += @{
                    message = "Azure CLI is not logged in. Please login to Azure CLI using 'az login -t `"00000000-0000-0000-0000-000000000000`"', replacing the empty GUID with your tenant ID."
                    result  = "Failure"
                }
                $hasFailure = $true
            }
        }
    } else {
        $results += @{
            message = "Azure CLI is not installed. Follow the instructions here: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
            result  = "Failure"
        }
        $hasFailure = $true
    }

    return @{
        Results                      = $results
        HasFailure                   = $hasFailure
        AzCliInstalledButNotLoggedIn = $azCliInstalledButNotLoggedIn
    }
}
