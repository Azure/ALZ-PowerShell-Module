#-------------------------------------------------------------------------
Set-Location -Path $PSScriptRoot
#-------------------------------------------------------------------------
$ModuleName = 'ALZ'
$PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
#-------------------------------------------------------------------------
if (Get-Module -Name $ModuleName -ErrorAction 'SilentlyContinue') {
    #if the module is already in memory, remove it
    Remove-Module -Name $ModuleName -Force
}
Import-Module $PathToManifest -Force
#-------------------------------------------------------------------------

InModuleScope 'ALZ' {
    Describe 'New-ALZDirectoryEnvironment Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Initialize config get the correct base values' {
            BeforeEach {
                Mock -CommandName New-Item
            }
            It 'Should create the correct folder structure' {
                New-ALZDirectoryEnvironment -OutputDirectory './config'
                Assert-MockCalled -CommandName New-Item -ParameterFilter { $Path -eq './config' } -Exactly 1
                Assert-MockCalled -CommandName New-Item -ParameterFilter { $Path -eq './config/alz-bicep-internal' } -Exactly 1
                Assert-MockCalled -CommandName New-Item -ParameterFilter { $Path -eq './config/.github/workflows' } -Exactly 1
                Assert-MockCalled -CommandName New-Item -ParameterFilter { $Path -eq './config/customization' } -Exactly 1
                Assert-MockCalled -CommandName New-Item -ParameterFilter { $Path -eq './config/orchestration' } -Exactly 1
            }
        }
    }
}
