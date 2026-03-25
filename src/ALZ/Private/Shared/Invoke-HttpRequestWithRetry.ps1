####################################
# Invoke-HttpRequestWithRetry.ps1  #
####################################
# Version: 0.1.0

<#
.SYNOPSIS
Invokes an HTTP request with automatic retry logic for transient errors.

.DESCRIPTION
Makes HTTP requests using Invoke-WebRequest or Invoke-RestMethod with
automatic retry for transient HTTP errors (408, 429, 500, 502, 503, 504).

.PARAMETER Uri
The URI to send the request to.

.PARAMETER Method
The HTTP method for the request. Defaults to GET.

.PARAMETER MaxRetryCount
Maximum number of retries for transient errors. Defaults to 10.

.PARAMETER RetryIntervalSeconds
Seconds to wait between retries. Defaults to 3.

.PARAMETER OutFile
If specified, downloads the response to this file path using Invoke-WebRequest.

.PARAMETER SkipHttpErrorCheck
If specified, does not throw on HTTP error status codes.
Returns the response object without error.

.PARAMETER TimeoutSec
Timeout in seconds for the HTTP request. If not specified, uses the default.

.PARAMETER Body
The body of the request.

.PARAMETER ContentType
The content type of the request body.

.PARAMETER Headers
Additional headers to include in the request.

.PARAMETER ReturnStatusCode
If specified alongside SkipHttpErrorCheck, returns a hashtable with
Result and StatusCode properties (similar to Invoke-GitHubApiRequest).

.EXAMPLE
Invoke-HttpRequestWithRetry -Uri "https://api.releases.hashicorp.com/v1/releases/terraform?limit=20"

.EXAMPLE
Invoke-HttpRequestWithRetry -Uri "https://example.com/file.zip" -OutFile "./file.zip"

.EXAMPLE
Invoke-HttpRequestWithRetry -Uri "https://example.com" -Method Head -SkipHttpErrorCheck -MaxRetryCount 0

.NOTES
# Release notes 25/03/2026 - V0.1.0:
- Initial release.
#>

function Invoke-HttpRequestWithRetry {
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
        [string] $OutFile,

        [Parameter(Mandatory = $false, HelpMessage = "If specified, does not throw on HTTP error status codes.")]
        [switch] $SkipHttpErrorCheck,

        [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds for the HTTP request.")]
        [int] $TimeoutSec,

        [Parameter(Mandatory = $false, HelpMessage = "The body of the request.")]
        [object] $Body,

        [Parameter(Mandatory = $false, HelpMessage = "The content type of the request body.")]
        [string] $ContentType,

        [Parameter(Mandatory = $false, HelpMessage = "Additional headers to include in the request.")]
        [hashtable] $Headers,

        [Parameter(Mandatory = $false, HelpMessage = "If specified, returns a hashtable with Result and StatusCode.")]
        [switch] $ReturnStatusCode
    )

    $isDownload = -not [string]::IsNullOrEmpty($OutFile)
    $transientStatusCodes = @(408, 429, 500, 502, 503, 504)
    $maxAttempts = $MaxRetryCount + 1

    # Build common parameters
    $commonParams = @{
        Uri         = $Uri
        Method      = $Method
        ErrorAction = "Stop"
    }

    if ($PSBoundParameters.ContainsKey("TimeoutSec")) {
        $commonParams["TimeoutSec"] = $TimeoutSec
    }

    if ($PSBoundParameters.ContainsKey("Body")) {
        $commonParams["Body"] = $Body
    }

    if ($PSBoundParameters.ContainsKey("ContentType")) {
        $commonParams["ContentType"] = $ContentType
    }

    if ($PSBoundParameters.ContainsKey("Headers")) {
        $commonParams["Headers"] = $Headers
    }

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            if ($isDownload) {
                Invoke-WebRequest @commonParams -OutFile $OutFile
                return
            }

            if ($SkipHttpErrorCheck) {
                $response = Invoke-WebRequest @commonParams -SkipHttpErrorCheck -UseBasicParsing

                $code = [int]$response.StatusCode

                if ($code -in $transientStatusCodes -and $attempt -lt $maxAttempts) {
                    Write-Warning "Request to $Uri returned status $code (attempt $attempt of $maxAttempts). Retrying in $RetryIntervalSeconds seconds..."
                    Start-Sleep -Seconds $RetryIntervalSeconds
                    continue
                }

                if ($ReturnStatusCode) {
                    return @{
                        Result     = $response
                        StatusCode = $code
                    }
                }

                return $response
            }

            return (Invoke-WebRequest @commonParams -UseBasicParsing)
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
