####################################
# Invoke-GitHubApiRequest.ps1     #
####################################
# Version: 0.1.0

<#
.SYNOPSIS
Invokes a GitHub API request with optional authentication and retry logic.

.DESCRIPTION
Makes HTTP requests to GitHub APIs or downloads files from GitHub.
If the GitHub CLI (gh) is installed and authenticated, the auth token is
automatically included in request headers to increase rate limits.
Transient errors (HTTP 408, 429, 500, 502, 503, 504) are retried up to
a configurable number of attempts.

.PARAMETER Uri
The URI to send the request to.

.PARAMETER Method
The HTTP method for the request. Defaults to GET.

.PARAMETER MaxRetryCount
Maximum number of retries for transient errors. Defaults to 10.

.PARAMETER RetryIntervalSeconds
Seconds to wait between retries. Defaults to 3.

.PARAMETER OutputFile
If specified, downloads the response to this file path using Invoke-WebRequest.

.PARAMETER SkipHttpErrorCheck
If specified, does not throw on HTTP error status codes.
Returns a hashtable with Result and StatusCode properties.

.EXAMPLE
Invoke-GitHubApiRequest -Uri "https://api.github.com/repos/Azure/ALZ/releases/latest"

.EXAMPLE
Invoke-GitHubApiRequest -Uri "https://api.github.com/repos/Azure/ALZ/releases/latest" -SkipHttpErrorCheck

.EXAMPLE
Invoke-GitHubApiRequest -Uri "https://github.com/Azure/ALZ/archive/refs/tags/v1.0.0.zip" -OutputFile "./release.zip"

.NOTES
# Release notes 25/03/2026 - V0.1.0:
- Initial release.
#>

function Invoke-GitHubApiRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "The URI to send the request to.")]
        [string] $Uri,

        [Parameter(Mandatory = $false, HelpMessage = "The HTTP method for the request.")]
        [string] $Method = "GET",

        [Parameter(Mandatory = $false, HelpMessage = "Maximum number of retries for transient errors.")]
        [int] $MaxRetryCount = 10,

        [Parameter(Mandatory = $false, HelpMessage = "Seconds to wait between retries.")]
        [int] $RetryIntervalSeconds = 3,

        [Parameter(Mandatory = $false, HelpMessage = "If specified, downloads the response to this file path.")]
        [string] $OutputFile,

        [Parameter(Mandatory = $false, HelpMessage = "If specified, does not throw on HTTP error status codes.")]
        [switch] $SkipHttpErrorCheck
    )

    # Build auth headers from gh CLI if available
    $headers = @{}
    $ghCommand = Get-Command "gh" -ErrorAction SilentlyContinue
    if ($null -ne $ghCommand) {
        $null = & gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $token = & gh auth token 2>&1
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($token)) {
                $headers["Authorization"] = "Bearer $($token.Trim())"
                Write-Verbose "GitHub CLI authentication token found. Using authenticated requests."
            }
        } else {
            Write-Verbose "GitHub CLI is installed but not authenticated. Proceeding without authentication."
        }
    } else {
        Write-Verbose "GitHub CLI is not installed. Proceeding without authentication."
    }

    $isDownload = -not [string]::IsNullOrEmpty($OutputFile)
    $transientStatusCodes = @(408, 429, 500, 502, 503, 504)
    $maxAttempts = $MaxRetryCount + 1

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            if ($isDownload) {
                Invoke-WebRequest -Uri $Uri -Method $Method -Headers $headers -OutFile $OutputFile -ErrorAction Stop
                return
            }

            if ($SkipHttpErrorCheck) {
                $result = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -SkipHttpErrorCheck -StatusCodeVariable "responseStatusCode"

                $code = [int]$responseStatusCode

                if ($code -in $transientStatusCodes -and $attempt -lt $maxAttempts) {
                    Write-Warning "Request to $Uri returned status $code (attempt $attempt of $maxAttempts). Retrying in $RetryIntervalSeconds seconds..."
                    Start-Sleep -Seconds $RetryIntervalSeconds
                    continue
                }

                return @{
                    Result     = $result
                    StatusCode = $code
                }
            }

            return (Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -ErrorAction Stop)
        } catch {
            $responseCode = $null
            if ($_.Exception.Response) {
                $responseCode = [int]$_.Exception.Response.StatusCode
            }

            $isTransient = $responseCode -in $transientStatusCodes

            if ($isTransient -and $attempt -lt $maxAttempts) {
                Write-Warning "Request to $Uri failed with status $responseCode (attempt $attempt of $maxAttempts). Retrying in $RetryIntervalSeconds seconds..."
                Start-Sleep -Seconds $RetryIntervalSeconds
            } else {
                throw
            }
        }
    }
}
