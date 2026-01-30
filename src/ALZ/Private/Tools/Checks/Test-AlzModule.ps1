function Test-AlzModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$CheckVersion = $true,
        [Parameter(Mandatory = $false)]
        [switch]$AllowContinueOnFailure
    )

    $results = @()
    $hasFailure = $false
    $currentScope = "CurrentUser"

    $importedModule = Get-Module -Name ALZ
    $isDevelopmentModule = ($null -ne $importedModule -and $importedModule.Version -eq "0.1.0")

    if ((-not $CheckVersion) -or $isDevelopmentModule) {
        Write-Verbose "Skipping ALZ module version check"

        if($isDevelopmentModule) {
            $results += @{
                message = "ALZ module version is 0.1.0. Skipping version check as this is a development module."
                result  = "Warning"
            }
        } elseif (-not $CheckVersion) {
            $results += @{
                message = "ALZ module version check was skipped as 'AlzModuleVersion' was not included in Checks."
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
            if($AllowContinueOnFailure.IsPresent) {
                $results += @{
                    message = "ALZ module is not correctly installed. Please install the latest version using 'Install-PSResource -Name ALZ'. Continuing as -destroy flag is set."
                    result  = "Warning"
                }
            } else {
                $results += @{
                    message = "ALZ module is not correctly installed. Please install the latest version using 'Install-PSResource -Name ALZ'."
                    result  = "Failure"
                }
                $hasFailure = $true
            }
        }

        $alzModuleLatestVersion = Find-PSResource -Name ALZ
        if ($null -ne $alzModuleCurrentVersion) {
            if ($alzModuleCurrentVersion.Version -lt $alzModuleLatestVersion.Version) {
                if($AllowContinueOnFailure.IsPresent) {
                    $results += @{
                        message = "ALZ module is not the latest version. Your version: $($alzModuleCurrentVersion.Version), Latest version: $($alzModuleLatestVersion.Version). Please update to the latest version using 'Update-PSResource -Name ALZ'. Continuing as -destroy flag is set."
                        result  = "Warning"
                    }
                } else {
                    $results += @{
                        message = "ALZ module is not the latest version. Your version: $($alzModuleCurrentVersion.Version), Latest version: $($alzModuleLatestVersion.Version). Please update to the latest version using 'Update-PSResource -Name ALZ'."
                        result  = "Failure"
                    }
                    $hasFailure = $true
                }
            } else {
                if($importedModule.Version -lt $alzModuleLatestVersion.Version) {
                    Write-Verbose "Imported ALZ module version ($($importedModule.Version)) is older than the latest installed version ($($alzModuleLatestVersion.Version)), re-importing module"

                    if($AllowContinueOnFailure.IsPresent) {
                        $results += @{
                            message = "ALZ module has the latest version installed, but not imported. Imported version: ($($importedModule.Version)). Please re-import the module using 'Remove-Module -Name ALZ; Import-Module -Name ALZ -Global' to use the latest version. Continuing as -destroy flag is set."
                            result  = "Warning"
                        }
                    } else {
                        $results += @{
                            message = "ALZ module has the latest version installed, but not imported. Imported version: ($($importedModule.Version)). Please re-import the module using 'Remove-Module -Name ALZ; Import-Module -Name ALZ -Global' to use the latest version."
                            result  = "Failure"
                        }
                        $hasFailure = $true
                    }
                } else {
                    $results += @{
                        message = "ALZ module is the latest version ($($alzModuleCurrentVersion.Version))."
                        result  = "Success"
                    }
                }
            }
        }
    }

    return @{
        Results      = $results
        HasFailure   = $hasFailure
        CurrentScope = $currentScope
    }
}
