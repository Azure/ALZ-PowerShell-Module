function Test-NetworkConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int] $HttpRequestMaxRetryCount = 0,

        [Parameter(Mandatory = $false)]
        [int] $HttpRequestRetryIntervalSeconds = 3,

        [Parameter(Mandatory = $false)]
        [int] $HttpRequestTimeoutSeconds = 10
    )

    $results = @()
    $hasFailure = $false

    Write-ToConsoleLog "Checking network connectivity to required endpoints..."
    Write-Verbose "Checking network connectivity to required endpoints"

    $endpoints = @(
        @{ Uri = "https://api.github.com";             Description = "GitHub API (release lookups)" },
        @{ Uri = "https://github.com";                 Description = "GitHub (module downloads)" },
        @{ Uri = "https://api.releases.hashicorp.com"; Description = "HashiCorp Releases API (Terraform version)" },
        @{ Uri = "https://releases.hashicorp.com";     Description = "HashiCorp Releases (Terraform binary download)" },
        @{ Uri = "https://management.azure.com";       Description = "Azure Management API" },
        @{ Uri = "https://www.powershellgallery.com";  Description = "PowerShell Gallery (module installs/updates)" }
    )

    foreach ($endpoint in $endpoints) {
        Write-Verbose "Testing network connectivity to $($endpoint.Uri)"
        try {
            if ($endpoint.Uri -eq "https://api.github.com") {
                $response = Invoke-GitHubApiRequest -Uri $endpoint.Uri -Method Head -SkipHttpErrorCheck -MaxRetryCount $HttpRequestMaxRetryCount -RetryIntervalSeconds $HttpRequestRetryIntervalSeconds -TimeoutSec $HttpRequestTimeoutSeconds
                $statusCode = $null
                if ($null -ne $response) {
                    $statusCode = $response.StatusCode
                }
                if ($statusCode -eq 401 -or $statusCode -eq 403) {
                    $results += @{
                        message = "GitHub API ($($endpoint.Uri)) returned HTTP $statusCode. This is most often caused by an expired or invalid GitHub CLI authentication token, or by GitHub API rate limiting. If you have the GitHub CLI (gh) installed, run 'gh auth login' (or 'gh auth logout' followed by 'gh auth login') to refresh your credentials. Otherwise wait a few minutes for the rate limit to reset before retrying."
                        result  = "Failure"
                    }
                    $hasFailure = $true
                    continue
                }
            } else {
                Invoke-HttpRequestWithRetry -Uri $endpoint.Uri -Method Head -TimeoutSec $HttpRequestTimeoutSeconds -SkipHttpErrorCheck -MaxRetryCount $HttpRequestMaxRetryCount -RetryIntervalSeconds $HttpRequestRetryIntervalSeconds | Out-Null
            }
            $results += @{
                message = "Network connectivity to $($endpoint.Description) ($($endpoint.Uri)) is available."
                result  = "Success"
            }
        } catch {
            $results += @{
                message = "Cannot reach $($endpoint.Description) ($($endpoint.Uri)). Check network/firewall settings. Error: $($_.Exception.Message)"
                result  = "Failure"
            }
            $hasFailure = $true
        }
    }

    return @{
        Results    = $results
        HasFailure = $hasFailure
    }
}
