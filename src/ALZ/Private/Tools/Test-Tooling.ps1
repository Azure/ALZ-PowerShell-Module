function Test-Tooling {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("PowerShell", "Git", "AzureCli", "AzureEnvVars", "AzureCliOrEnvVars", "AzureLogin", "AlzModule", "AlzModuleVersion", "YamlModule", "YamlModuleAutoInstall", "GitHubCli", "AzureDevOpsCli")]
        [string[]]$Checks = @("PowerShell", "Git", "AzureCliOrEnvVars", "AzureLogin", "AlzModule", "AlzModuleVersion"),
        [Parameter(Mandatory = $false)]
        [switch]$destroy
    )

    $checkResults = @()
    $hasFailure = $false
    $azCliInstalledButNotLoggedIn = $false
    $currentScope = "CurrentUser"

    # Check PowerShell version
    if ($Checks -contains "PowerShell") {
        $result = Test-PowerShellVersion
        $checkResults += $result.Results
        if ($result.HasFailure) { $hasFailure = $true }
    }

    # Check Git installation
    if ($Checks -contains "Git") {
        $result = Test-GitInstallation
        $checkResults += $result.Results
        if ($result.HasFailure) { $hasFailure = $true }
    }

    # Check Azure Environment Variables only
    if ($Checks -contains "AzureEnvVars") {
        $result = Test-AzureEnvironmentVariable
        $checkResults += $result.Results
        if ($result.HasFailure) { $hasFailure = $true }
    }

    # Check Azure CLI only (used by Remove-PlatformLandingZone)
    if ($Checks -contains "AzureCli") {
        $requireLogin = $Checks -contains "AzureLogin"
        $result = Test-AzureCli -RequireLogin $requireLogin
        $checkResults += $result.Results
        if ($result.HasFailure) { $hasFailure = $true }
        if ($result.AzCliInstalledButNotLoggedIn) { $azCliInstalledButNotLoggedIn = $true }
    }

    # Check Azure CLI or Environment Variables (used by Deploy-Accelerator)
    # If env vars are valid, skip CLI check; otherwise check CLI
    if ($Checks -contains "AzureCliOrEnvVars") {
        $envResult = Test-AzureEnvironmentVariable
        $checkResults += $envResult.Results
        if ($envResult.HasFailure) { $hasFailure = $true }

        # Only check CLI if env vars are not valid
        if (-not $envResult.EnvVarsValid) {
            $requireLogin = $Checks -contains "AzureLogin"
            $cliResult = Test-AzureCli -RequireLogin $requireLogin
            $checkResults += $cliResult.Results
            if ($cliResult.HasFailure) { $hasFailure = $true }
            if ($cliResult.AzCliInstalledButNotLoggedIn) { $azCliInstalledButNotLoggedIn = $true }
        }
    }

    # Check ALZ Module
    if ($Checks -contains "AlzModule") {
        $checkVersion = $Checks -contains "AlzModuleVersion"
        $result = Test-AlzModule -CheckVersion $checkVersion -AllowContinueOnFailure:$destroy.IsPresent
        $checkResults += $result.Results
        if ($result.HasFailure) { $hasFailure = $true }
        if ($result.CurrentScope) { $currentScope = $result.CurrentScope }
    }

    # Check YAML Module
    if ($Checks -contains "YamlModule") {
        $autoInstall = $Checks -contains "YamlModuleAutoInstall"
        $result = Test-YamlModule -AutoInstall $autoInstall -Scope $currentScope
        $checkResults += $result.Results
        if ($result.HasFailure) { $hasFailure = $true }
    }

    # Check GitHub CLI
    if ($Checks -contains "GitHubCli") {
        $result = Test-GitHubCli
        $checkResults += $result.Results
        if ($result.HasFailure) { $hasFailure = $true }
    }

    # Check Azure DevOps CLI
    if ($Checks -contains "AzureDevOpsCli") {
        $result = Test-AzureDevOpsCli
        $checkResults += $result.Results
        if ($result.HasFailure) { $hasFailure = $true }
    }

    # Display results
    Write-Verbose "Showing check results"
    Write-Verbose $(ConvertTo-Json $checkResults -Depth 100)
    $checkResults | ForEach-Object {[PSCustomObject]$_} | Format-Table -Property @{
        Label = "Check Result"; Expression = {
            switch ($_.result) {
                'Success' { $color = "92"; break }
                'Failure' { $color = "91"; break }
                'Warning' { $color = "93"; break }
                default { $color = "0" }
            }
            $e = [char]27
            "$e[${color}m$($_.result)${e}[0m"
        }
    }, @{ Label = "Check Details"; Expression = {$_.message} }  -AutoSize -Wrap | Out-Host

    if($hasFailure) {
        Write-ToConsoleLog "Accelerator software requirements have no been met, please review and install the missing software." -IsError
        Write-ToConsoleLog "Cannot continue with Deployment..." -IsError
        throw "Accelerator software requirements have no been met, please review and install the missing software."
    }

    return @{
        AzCliInstalledButNotLoggedIn = $azCliInstalledButNotLoggedIn
    }
}

