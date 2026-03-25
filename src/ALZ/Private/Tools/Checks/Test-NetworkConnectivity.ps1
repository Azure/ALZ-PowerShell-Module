function Test-NetworkConnectivity {
    [CmdletBinding()]
    param()

    $results = @()
    $hasFailure = $false

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
                Invoke-GitHubApiRequest -Uri $endpoint.Uri -Method Head -SkipHttpErrorCheck -MaxRetryCount 0 | Out-Null
            } else {
                Invoke-WebRequest -Uri $endpoint.Uri -Method Head -TimeoutSec 10 -SkipHttpErrorCheck -ErrorAction Stop -UseBasicParsing | Out-Null
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
