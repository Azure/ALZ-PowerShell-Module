function Test-YamlModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$AutoInstall = $false,
        [Parameter(Mandatory = $false)]
        [string]$Scope = "CurrentUser"
    )

    $results = @()
    $hasFailure = $false

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
            $results += @{
                message = "powershell-yaml module is installed but was not imported, now imported (version $($yamlModule.Version))."
                result  = "Success"
            }
        } else {
            $results += @{
                message = "powershell-yaml module is installed and imported (version $($yamlModule.Version))."
                result  = "Success"
            }
        }
    } elseif (-not $AutoInstall) {
        Write-Verbose "powershell-yaml module is not installed, skipping installation attempt"
        $results += @{
            message = "powershell-yaml module is not installed. Please install it using 'Install-PSResource powershell-yaml -Scope $Scope'."
            result  = "Failure"
        }
        $hasFailure = $true
    } else {
        Write-Verbose "powershell-yaml module is not installed, attempting installation"
        $installResult = Install-PSResource powershell-yaml -TrustRepository -Scope $Scope 2>&1
        if($installResult -like "*Access to the path*") {
            Write-Verbose "Failed to install powershell-yaml module due to permission issues at $Scope scope."
            $results += @{
                message = "powershell-yaml module is not installed. Please install it using an admin terminal with 'Install-PSResource powershell-yaml -Scope $Scope'. Could not install due to permission issues."
                result  = "Failure"
            }
            $hasFailure = $true
        } elseif ($null -ne $installResult) {
            Write-Verbose "Failed to install powershell-yaml module: $installResult"
            $results += @{
                message = "powershell-yaml module is not installed. Please install it using 'Install-PSResource powershell-yaml -Scope $Scope'. Attempted installation error: $installResult"
                result  = "Failure"
            }
            $hasFailure = $true
        } else {
            $installedVersion = (Get-InstalledPSResource -Name powershell-yaml -Scope $Scope).Version
            $results += @{
                message = "powershell-yaml module was not installed, but has been successfully installed (version $installedVersion)."
                result  = "Success"
            }
        }
    }

    return @{
        Results    = $results
        HasFailure = $hasFailure
    }
}
