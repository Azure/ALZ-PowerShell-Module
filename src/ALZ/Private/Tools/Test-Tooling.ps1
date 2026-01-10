function Test-Tooling {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$skipAlzModuleVersionCheck,
        [Parameter(Mandatory = $false)]
        [switch]$checkYamlModule,
        [Parameter(Mandatory = $false)]
        [switch]$skipYamlModuleInstall,
        [Parameter(Mandatory = $false)]
        [switch]$skipAzureLoginCheck,
        [Parameter(Mandatory = $false)]
        [switch]$destroy
    )

    $checkResults = @()
    $hasFailure = $false
    $azCliInstalledButNotLoggedIn = $false

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

            # Check if Azure CLI is logged in
            Write-Verbose "Checking Azure CLI login status"
            $azCliAccount = $(az account show -o json 2>$null) | ConvertFrom-Json
            if ($azCliAccount) {
                $checkResults += @{
                    message = "Azure CLI is logged in. Tenant ID: $($azCliAccount.tenantId), Subscription: $($azCliAccount.name) ($($azCliAccount.id))"
                    result  = "Success"
                }
            } else {
                $azCliInstalledButNotLoggedIn = $true
                if ($skipAzureLoginCheck.IsPresent) {
                    $checkResults += @{
                        message = "Azure CLI is not logged in. Login will be prompted later."
                        result  = "Warning"
                    }
                } else {
                    $checkResults += @{
                        message = "Azure CLI is not logged in. Please login to Azure CLI using 'az login -t `"00000000-0000-0000-0000-000000000000`"', replacing the empty GUID with your tenant ID."
                        result  = "Failure"
                    }
                    $hasFailure = $true
                }
            }
        } else {
            $checkResults += @{
                message = "Azure CLI is not installed. Follow the instructions here: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
                result  = "Failure"
            }
            $hasFailure = $true
        }
    }

    $currentScope = "CurrentUser"

    $importedModule = Get-Module -Name ALZ
    $isDevelopmentModule = ($null -ne $importedModule -and $importedModule.Version -eq "0.1.0")
    if($skipAlzModuleVersionCheck.IsPresent -or $isDevelopmentModule) {
        Write-Verbose "Skipping ALZ module version check"

        if($isDevelopmentModule) {
            $checkResults += @{
                message = "ALZ module version is 0.1.0. Skipping version check as this is a development module."
                result  = "Warning"
            }
        } elseif ($skipAlzModuleVersionCheck.IsPresent) {
            $checkResults += @{
                message = "ALZ module version check was explicitly skipped using the -skipAlzModuleVersionRequirementsCheck parameter."
                result  = "Warning"
            }
        }
    } else {
        # Check if latest ALZ module is installed
        Write-Verbose "Checking ALZ module version"
        $alzModuleCurrentVersion = Get-InstalledPSResource -Name ALZ 2>$null | Select-Object -Property Name, Version | Sort-Object Version -Descending | Select-Object -First 1
        if($null -eq $alzModuleCurrentVersion) {
            Write-Verbose "ALZ module not found in CurrentUser scope, checking AllUsers scope"
            $alzModuleCurrentVersion = Get-InstalledPSResource -Name ALZ -Scope AllUsers 2>$null | Select-Object -Property Name, Version | Sort-Object Version -Descending | Select-Object -First 1
            if($null -ne $alzModuleCurrentVersion) {
                Write-Verbose "ALZ module found in AllUsers scope"
                $currentScope = "AllUsers"
            }
        }

        if($null -eq $alzModuleCurrentVersion) {
            if($destroy.IsPresent) {
                $checkResults += @{
                    message = "ALZ module is not correctly installed. Please install the latest version using 'Install-PSResource -Name ALZ'. Continuing as -destroy flag is set."
                    result  = "Warning"
                }
            } else {
                $checkResults += @{
                    message = "ALZ module is not correctly installed. Please install the latest version using 'Install-PSResource -Name ALZ'."
                    result  = "Failure"
                }
                $hasFailure = $true
            }
        }
        $alzModuleLatestVersion = Find-PSResource -Name ALZ
        if ($null -ne $alzModuleCurrentVersion) {
            if ($alzModuleCurrentVersion.Version -lt $alzModuleLatestVersion.Version) {
                if($destroy.IsPresent) {
                    $checkResults += @{
                        message = "ALZ module is not the latest version. Your version: $($alzModuleCurrentVersion.Version), Latest version: $($alzModuleLatestVersion.Version). Please update to the latest version using 'Update-PSResource -Name ALZ'. Continuing as -destroy flag is set."
                        result  = "Warning"
                    }
                } else {
                    $checkResults += @{
                        message = "ALZ module is not the latest version. Your version: $($alzModuleCurrentVersion.Version), Latest version: $($alzModuleLatestVersion.Version). Please update to the latest version using 'Update-PSResource -Name ALZ'."
                        result  = "Failure"
                    }
                    $hasFailure = $true
                }
            } else {
                if($importedModule.Version -lt $alzModuleLatestVersion.Version) {
                    Write-Verbose "Imported ALZ module version ($($importedModule.Version)) is older than the latest installed version ($($alzModuleLatestVersion.Version)), re-importing module"

                    if($destroy.IsPresent) {
                        $checkResults += @{
                            message = "ALZ module has the latest version installed, but not imported. Imported version: ($($importedModule.Version)). Please re-import the module using 'Remove-Module -Name ALZ; Import-Module -Name ALZ -Global' to use the latest version. Continuing as -destroy flag is set."
                            result  = "Warning"
                        }
                    } else {
                        $checkResults += @{
                            message = "ALZ module has the latest version installed, but not imported. Imported version: ($($importedModule.Version)). Please re-import the module using 'Remove-Module -Name ALZ; Import-Module -Name ALZ -Global' to use the latest version."
                            result  = "Failure"
                        }
                        $hasFailure = $true
                    }
                } else {
                    $checkResults += @{
                        message = "ALZ module is the latest version ($($alzModuleCurrentVersion.Version))."
                        result  = "Success"
                    }
                }
            }
        }
    }

    # Check if powershell-yaml module is installed (only when YAML files are being used)
    if ($checkYamlModule.IsPresent) {
        Write-Verbose "Checking powershell-yaml module installation"
        $yamlModule = Get-InstalledPSResource -Name powershell-yaml 2> $null | Select-Object -Property Name, Version | Sort-Object Version -Descending | Select-Object -First 1
        if($null -eq $yamlModule) {
            Write-Verbose "powershell-yaml module not found in CurrentUser scope, checking AllUsers scope"
            $yamlModule = Get-InstalledPSResource -Name powershell-yaml -Scope AllUsers 2> $null | Select-Object -Property Name, Version | Sort-Object Version -Descending | Select-Object -First 1
        }

        if ($yamlModule) {
            # Import powershell-yaml module if not already loaded
            if (-not (Get-Module -Name powershell-yaml)) {
                Write-Verbose "Importing powershell-yaml module version $($yamlModule.Version)"
                Import-Module -Name powershell-yaml -RequiredVersion $yamlModule.Version -Global
                $checkResults += @{
                    message = "powershell-yaml module is installed but was not imported, now imported (version $($yamlModule.Version))."
                    result  = "Success"
                }
            } else {
                $checkResults += @{
                    message = "powershell-yaml module is installed and imported (version $($yamlModule.Version))."
                    result  = "Success"
                }
            }
        } elseif ($skipYamlModuleInstall.IsPresent) {
            Write-Verbose "powershell-yaml module is not installed, skipping installation attempt"
            $checkResults += @{
                message = "powershell-yaml module is not installed. Please install it using 'Install-PSResource powershell-yaml -Scope $currentScope'."
                result  = "Failure"
            }
            $hasFailure = $true
        } else {
            Write-Verbose "powershell-yaml module is not installed, attempting installation"
            $installResult = Install-PSResource powershell-yaml -TrustRepository -Scope $currentScope 2>&1
            if($installResult -like "*Access to the path*") {
                Write-Verbose "Failed to install powershell-yaml module due to permission issues at $currentScope scope."
                $checkResults += @{
                    message = "powershell-yaml module is not installed. Please install it using an admin terminal with 'Install-PSResource powershell-yaml -Scope $currentScope'. Could not install due to permission issues."
                    result  = "Failure"
                }
                $hasFailure = $true
            } elseif ($null -ne $installResult) {
                Write-Verbose "Failed to install powershell-yaml module: $installResult"
                $checkResults += @{
                    message = "powershell-yaml module is not installed. Please install it using 'Install-PSResource powershell-yaml -Scope $currentScope'. Attempted installation error: $installResult"
                    result  = "Failure"
                }
                $hasFailure = $true
            } else {
                $installedVersion = (Get-InstalledPSResource -Name powershell-yaml -Scope $currentScope).Version
                $checkResults += @{
                    message = "powershell-yaml module was not installed, but has been successfully installed (version $installedVersion)."
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
    }, @{ Label = "Check Details"; Expression = {$_.message} }  -AutoSize -Wrap | Out-Host

    if($hasFailure) {
        Write-InformationColored "Accelerator software requirements have no been met, please review and install the missing software." -ForegroundColor Red -InformationAction Continue
        Write-InformationColored "Cannot continue with Deployment..." -ForegroundColor Red -InformationAction Continue
        throw "Accelerator software requirements have no been met, please review and install the missing software."
    }

    return @{
        AzCliInstalledButNotLoggedIn = $azCliInstalledButNotLoggedIn
    }
}
