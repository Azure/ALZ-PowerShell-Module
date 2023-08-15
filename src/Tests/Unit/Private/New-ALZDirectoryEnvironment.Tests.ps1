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
                Mock -CommandName New-Item -MockWith { }
            }
            It 'Should create the correct folder structure' {
                $basePath = "./config"

                New-ALZDirectoryEnvironment -OutputDirectory $basePath
                Should -Invoke -CommandName New-Item -ParameterFilter { $Path -eq './config' }
                Should -Invoke -CommandName New-Item -ParameterFilter { $Path -eq $(Join-Path $basePath 'upstream-releases') } -Exactly 1
                Should -Invoke -CommandName New-Item -ParameterFilter { $Path -eq $(Join-Path $basePath '.github' 'workflows') -or $Path -eq $(Join-Path $basePath '.azuredevops' 'pipelines') } -Exactly 1
                Should -Invoke -CommandName New-Item -ParameterFilter { $Path -eq $(Join-Path $basePath 'config') } -Exactly 1
            }
        }
    }
}
