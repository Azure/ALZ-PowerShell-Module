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

        [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds for the HTTP request.")]
        [int] $TimeoutSec,

        [Parameter(Mandatory = $false, HelpMessage = "If specified, does not throw on HTTP error status codes.")]
        [switch] $SkipHttpErrorCheck
    )

    # Build auth headers from gh CLI if available
    $headers = @{}
    $usedGhToken = $false
    $ghCommand = Get-Command "gh" -ErrorAction SilentlyContinue
    if ($null -ne $ghCommand) {
        $null = & gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $token = & gh auth token 2>&1
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($token)) {
                $headers["Authorization"] = "Bearer $($token.Trim())"
                $usedGhToken = $true
                Write-Verbose "GitHub CLI authentication token found. Using authenticated requests."
            }
        } else {
            Write-Verbose "GitHub CLI is installed but not authenticated. Proceeding without authentication."
        }
    } else {
        Write-Verbose "GitHub CLI is not installed. Proceeding without authentication."
    }

    # Build parameters for the generic retry cmdlet
    $retryParams = @{
        Uri                  = $Uri
        Method               = $Method
        MaxRetryCount        = $MaxRetryCount
        RetryIntervalSeconds = $RetryIntervalSeconds
    }

    if ($PSBoundParameters.ContainsKey("TimeoutSec")) {
        $retryParams["TimeoutSec"] = $TimeoutSec
    }

    if ($headers.Count -gt 0) {
        $retryParams["Headers"] = $headers
    }

    # If the gh CLI token is rejected (401/403), the token is likely expired or
    # has insufficient scopes. Drop the Authorization header so the next attempt
    # is anonymous (subject to lower rate limits) and warn the user to refresh
    # their gh credentials with `gh auth login`.
    function Disable-AuthAndWarn {
        param([int] $StatusCode)
        Write-ToConsoleLog "GitHub API request to $Uri was rejected with status $StatusCode while using the GitHub CLI authentication token. The token may be expired or have insufficient scopes. Retrying without authentication. To resolve this permanently, run 'gh auth login' (or 'gh auth logout' followed by 'gh auth login') to refresh your GitHub CLI credentials." -IsWarning
        $retryParams.Remove("Headers")
    }

    function Get-StatusCodeFromError {
        param($ErrorRecord)
        if ($ErrorRecord.Exception.Response) {
            return [int]$ErrorRecord.Exception.Response.StatusCode
        }
        return $null
    }

    # File download — delegate directly
    if (-not [string]::IsNullOrEmpty($OutputFile)) {
        try {
            Invoke-HttpRequestWithRetry @retryParams -OutFile $OutputFile
        } catch {
            $statusCode = Get-StatusCodeFromError $_
            if ($usedGhToken -and ($statusCode -eq 401 -or $statusCode -eq 403)) {
                Disable-AuthAndWarn -StatusCode $statusCode
                Invoke-HttpRequestWithRetry @retryParams -OutFile $OutputFile
            } else {
                throw
            }
        }
        return
    }

    # API call with SkipHttpErrorCheck — parse JSON and return Result/StatusCode hashtable
    if ($SkipHttpErrorCheck) {
        $response = Invoke-HttpRequestWithRetry @retryParams -SkipHttpErrorCheck -ReturnStatusCode

        if ($usedGhToken -and ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403)) {
            Disable-AuthAndWarn -StatusCode $response.StatusCode
            $response = Invoke-HttpRequestWithRetry @retryParams -SkipHttpErrorCheck -ReturnStatusCode
        }

        $parsed = $null
        if (-not [string]::IsNullOrWhiteSpace($response.Result.Content)) {
            $parsed = $response.Result.Content | ConvertFrom-Json
        }

        return @{
            Result     = $parsed
            StatusCode = $response.StatusCode
        }
    }

    # Standard API call — parse JSON and return the object
    try {
        $response = Invoke-HttpRequestWithRetry @retryParams
    } catch {
        $statusCode = Get-StatusCodeFromError $_
        if ($usedGhToken -and ($statusCode -eq 401 -or $statusCode -eq 403)) {
            Disable-AuthAndWarn -StatusCode $statusCode
            $response = Invoke-HttpRequestWithRetry @retryParams
        } else {
            throw
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        return ($response.Content | ConvertFrom-Json)
    }
}
