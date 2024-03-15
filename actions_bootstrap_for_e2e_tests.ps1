# Bootstrap dependencies

# https://docs.microsoft.com/powershell/module/packagemanagement/get-packageprovider
Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null

# https://docs.microsoft.com/powershell/module/powershellget/set-psrepository
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# List of PowerShell Modules required for the build
$modulesToInstall = [System.Collections.ArrayList]::new()
# https://github.com/nightroman/Invoke-Build
$null = $modulesToInstall.Add(([PSCustomObject]@{
            ModuleName    = 'InvokeBuild'
            ModuleVersion = '5.10.2'
        }))

'Installing PowerShell Modules'
foreach ($module in $modulesToInstall) {
    $installSplat = @{
        Name               = $module.ModuleName
        RequiredVersion    = $module.ModuleVersion
        Repository         = 'PSGallery'
        SkipPublisherCheck = $true
        Force              = $true
        ErrorAction        = 'Stop'
    }
    try {
        Install-Module @installSplat
        Import-Module -Name $module.ModuleName -ErrorAction Stop
        '  - Successfully installed {0}' -f $module.ModuleName
    } catch {
        $message = 'Failed to install {0}' -f $module.ModuleName
        "  - $message"
        throw
    }
}

