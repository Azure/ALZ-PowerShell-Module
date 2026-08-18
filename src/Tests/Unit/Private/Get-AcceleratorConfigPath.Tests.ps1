#-------------------------------------------------------------------------
Set-Location -Path $PSScriptRoot
#-------------------------------------------------------------------------
$ModuleName = 'ALZ'
$PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
#-------------------------------------------------------------------------
if (Get-Module -Name $ModuleName -ErrorAction 'SilentlyContinue') {
    Remove-Module -Name $ModuleName -Force
}
Import-Module $PathToManifest -Force
#-------------------------------------------------------------------------

InModuleScope 'ALZ' {
    Describe 'Get-AcceleratorConfigPath Function Tests' -Tag Unit {
        It 'returns the bicep configuration files and existing additional folders' {
            $configFolderPath = Join-Path $TestDrive 'config'
            New-Item -Path (Join-Path $configFolderPath 'templates') -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $configFolderPath '.config') -ItemType Directory -Force | Out-Null

            $result = Get-AcceleratorConfigPath -ConfigFolderPath $configFolderPath -IacType 'bicep'

            $result.InputConfigFilePaths | Should -Be @(
                "$configFolderPath/inputs.yaml"
                "$configFolderPath/platform-landing-zone.yaml"
            )
            $result.StarterAdditionalFiles | Should -Be @(
                "$configFolderPath/templates"
                "$configFolderPath/.config"
            )
        }

        It 'does not return missing bicep additional folders' {
            $configFolderPath = Join-Path $TestDrive 'config-without-additional-folders'
            New-Item -Path $configFolderPath -ItemType Directory -Force | Out-Null

            $result = Get-AcceleratorConfigPath -ConfigFolderPath $configFolderPath -IacType 'bicep'

            $result.StarterAdditionalFiles | Should -BeNullOrEmpty
        }
    }
}
