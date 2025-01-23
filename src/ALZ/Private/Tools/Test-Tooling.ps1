function Test-Tooling {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$skipAlzModuleVersionCheck
    )

    $checkResults = @()
    $hasFailure = $false

    # Check if PowerShell is the correct version
    Write-Verbose "Checking PowerShell version"
    $powerShellVersionTable = $PSVersionTable
    $powerShellVersion = $powerShellVersionTable.PSVersion.ToString()
    if ($powerShellVersionTable.PSVersion.Major -lt 7) {
        $checkResults += @{
            message = "PowerShell version $powerShellVersion is not supported. Please upgrade to PowerShell 7.4 or higher. Either switch to the `pwsh` prompt or follow the instructions here: https://aka.ms/install-powershell"
            result  = "Failure"
        }
        $hasFailure = $true
    } elseif ($powerShellVersionTable.PSVersion.Major -eq 7 -and $powerShellVersionTable.PSVersion.Minor -lt 4) {
        $checkResults += @{
            message = "PowerShell version $powerShellVersion is not supported. Please upgrade to PowerShell 7.4 or higher. Either switch to the `pwsh` prompt or follow the instructions here: https://aka.ms/install-powershell"
            result  = "Failure"
        }
        $hasFailure = $true
    } else {
        $checkResults += @{
            message = "PowerShell version $powerShellVersion is supported."
            result  = "Success"
        }
    }

    # Check if Git is installed
    Write-Verbose "Checking Git installation"
    $gitPath = Get-Command git -ErrorAction SilentlyContinue
    if ($gitPath) {
        $checkResults += @{
            message = "Git is installed."
            result  = "Success"
        }
    } else {
        $checkResults += @{
            message = "Git is not installed. Follow the instructions here: https://git-scm.com/downloads"
            result  = "Failure"
        }
        $hasFailure = $true
    }

    # Check if using Service Principal Auth
    Write-Verbose "Checking Azure environment variables"
    $nonAzCliEnvVars = @(
        "ARM_CLIENT_ID",
        "ARM_SUBSCRIPTION_ID",
        "ARM_TENANT_ID"
    )

    $envVarsSet = $true
    $envVarValid = $true
    $envVarUnique = $true
    $envVarAtLeastOneSet = $false
    $envVarsWithValue = @()
    $checkedEnvVars = @()
    foreach($envVar in $nonAzCliEnvVars) {
        $envVarValue = [System.Environment]::GetEnvironmentVariable($envVar)
        if($envVarValue -eq $null -or $envVarValue -eq "" ) {
            $envVarsSet = $false
            continue
        }
        $envVarAtLeastOneSet = $true
        $envVarsWithValue += $envVar
        if($envVarValue -notmatch("^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$")) {
            $envVarValid = $false
            continue
        }
        if($checkedEnvVars -contains $envVarValue) {
            $envVarUnique = $false
            continue
        }
        $checkedEnvVars += $envVarValue
    }

    if($envVarsSet) {
        Write-Verbose "Using Service Principal Authentication, skipping Azure CLI checks"
        if($envVarValid -and $envVarUnique) {
            $checkResults += @{
                message = "Azure environment variables are set and are valid unique GUIDs."
                result  = "Success"
            }
        }

        if(-not $envVarValid) {
            $checkResults += @{
                message = "Azure environment variables are set, but are not all valid GUIDs."
                result  = "Failure"
            }
            $hasFailure = $true
        }

        if (-not $envVarUnique) {
            $envVarValidationOutput = ""
            foreach($envVar in $nonAzCliEnvVars) {
                $envVarValue = [System.Environment]::GetEnvironmentVariable($envVar)
                $envVarValidationOutput += " $envVar ($envVarValue)"
            }
            $checkResults += @{
                message = "Azure environment variables are set, but are not unique GUIDs. There is at least one duplicate:$envVarValidationOutput."
                result  = "Failure"
            }
            $hasFailure = $true
        }
    } else {
        if($envVarAtLeastOneSet) {
            $envVarValidationOutput = ""
            foreach($envVar in $envVarsWithValue) {
                $envVarValue = [System.Environment]::GetEnvironmentVariable($envVar)
                $envVarValidationOutput += " $envVar ($envVarValue)"
            }
            $checkResults += @{
                message = "At least one environment variable is set, but the other expected environment variables are not set. This could cause Terraform to fail in unexpected ways. Set environment variables:$envVarValidationOutput."
                result  = "Warning"
            }
        }

        # Check if Azure CLI is installed
        Write-Verbose "Checking Azure CLI installation"
        $azCliPath = Get-Command az -ErrorAction SilentlyContinue
        if ($azCliPath) {
            $checkResults += @{
                message = "Azure CLI is installed."
                result  = "Success"
            }
        } else {
            $checkResults += @{
                message = "Azure CLI is not installed. Follow the instructions here: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
                result  = "Failure"
            }
            $hasFailure = $true
        }

        # Check if Azure CLI is logged in
        Write-Verbose "Checking Azure CLI login status"
        $azCliAccount = $(az account show -o json) | ConvertFrom-Json
        if ($azCliAccount) {
            $checkResults += @{
                message = "Azure CLI is logged in. Tenant ID: $($azCliAccount.tenantId), Subscription: $($azCliAccount.name) ($($azCliAccount.id))"
                result  = "Success"
            }
        } else {
            $checkResults += @{
                message = "Azure CLI is not logged in. Please login to Azure CLI using 'az login -t `"00000000-0000-0000-0000-000000000000}`"', replacing the empty GUID with your tenant ID."
                result  = "Failure"
            }
            $hasFailure = $true
        }
    }

    if($skipAlzModuleVersionCheck.IsPresent) {
        Write-Verbose "Skipping ALZ module version check"
    } else {
        # Check if latest ALZ module is installed
        Write-Verbose "Checking ALZ module version"
        $alzModuleCurrentVersion = Get-InstalledModule -Name ALZ -ErrorAction SilentlyContinue
        if($null -eq $alzModuleCurrentVersion) {
            $checkResults += @{
                message = "ALZ module is not correctly installed. Please install the latest version using 'Install-Module ALZ'."
                result  = "Failure"
            }
            $hasFailure = $true
        }
        $alzModuleLatestVersion = Find-Module -Name ALZ
        if ($null -ne $alzModuleCurrentVersion) {
            if ($alzModuleCurrentVersion.Version -lt $alzModuleLatestVersion.Version) {
                $checkResults += @{
                    message = "ALZ module is not the latest version. Your version: $($alzModuleCurrentVersion.Version), Latest version: $($alzModuleLatestVersion.Version). Please update to the latest version using 'Update-Module ALZ'."
                    result  = "Failure"
                }
                $hasFailure = $true
            } else {
                $checkResults += @{
                    message = "ALZ module is the latest version ($($alzModuleCurrentVersion.Version))."
                    result  = "Success"
                }
            }
        }
    }

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
    }, @{ Label = "Check Details"; Expression = {$_.message} }  -AutoSize -Wrap

    if($hasFailure) {
        Write-InformationColored "Accelerator software requirements have no been met, please review and install the missing software." -ForegroundColor Red -InformationAction Continue
        Write-InformationColored "Cannot continue with Deployment..." -ForegroundColor Red -InformationAction Continue
        throw "Accelerator software requirements have no been met, please review and install the missing software."
    }
}
