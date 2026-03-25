function Test-AcceleratorRequirement {
    <#
    .SYNOPSIS
        Test that the Accelerator software requirements are met
    .DESCRIPTION
        This will check for the pre-requisite software and network connectivity to the external endpoints required by the Accelerator.
    .EXAMPLE
        C:\PS> Test-AcceleratorRequirement
    .EXAMPLE
        C:\PS> Test-AcceleratorRequirement -Verbose
    .EXAMPLE
        C:\PS> Test-AcceleratorRequirement -Checks @("GitHubCli")
    .OUTPUTS
        Boolean - True if all requirements are met, false if not.
    .NOTES
        This function is used by the Deploy-Accelerator function to ensure that the software requirements are met before attempting run the Accelerator.
    .COMPONENT
        ALZ
    #>
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Specifies which checks to run. Valid values: PowerShell, Git, AzureCli, AzureEnvVars, AzureCliOrEnvVars, AzureLogin, AlzModule, AlzModuleVersion, YamlModule, YamlModuleAutoInstall, GitHubCli, AzureDevOpsCli, NetworkConnectivity"
        )]
        [ValidateSet("PowerShell", "Git", "AzureCli", "AzureEnvVars", "AzureCliOrEnvVars", "AzureLogin", "AlzModule", "AlzModuleVersion", "YamlModule", "YamlModuleAutoInstall", "GitHubCli", "AzureDevOpsCli", "NetworkConnectivity")]
        [string[]]$Checks = @("PowerShell", "Git", "AzureCliOrEnvVars", "AzureLogin", "AlzModule", "AlzModuleVersion", "NetworkConnectivity"),

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Maximum number of retries for transient HTTP request errors during network connectivity checks. Defaults to 0."
        )]
        [Alias("hrmrc")]
        [Alias("httpRequestMaxRetryCount")]
        [int] $http_request_max_retry_count = 0,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Seconds to wait between retries for transient HTTP request errors during network connectivity checks. Defaults to 3."
        )]
        [Alias("hrris")]
        [Alias("httpRequestRetryIntervalSeconds")]
        [int] $http_request_retry_interval_seconds = 3,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Timeout in seconds for HTTP requests during network connectivity checks. Defaults to 10."
        )]
        [Alias("hrts")]
        [Alias("httpRequestTimeoutSeconds")]
        [int] $http_request_timeout_seconds = 10
    )
    $toolingParams = @{
        Checks                          = $Checks
        HttpRequestMaxRetryCount        = $http_request_max_retry_count
        HttpRequestRetryIntervalSeconds = $http_request_retry_interval_seconds
        HttpRequestTimeoutSeconds       = $http_request_timeout_seconds
    }
    Test-Tooling @toolingParams
}
