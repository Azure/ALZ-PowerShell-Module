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
    Describe 'Test-ALZRequirement Public Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Non Az Module' {
            BeforeEach {
                Mock -CommandName Get-Module -MockWith {
                    $null
                }
            }
            It 'should return the not met for non AZ module' {
                Test-ALZRequirement | Should -BeExactly "ALZ requirements are not met."
            }
        }
        Context 'Incompatible Powershell version lower them 7' {
            BeforeEach {
                Mock -CommandName Get-PSVersion -MockWith {
                    [PSCustomObject]@{
                        PSVersion = [PSCustomObject]@{
                            Major = 6
                            Minor = 2
                        }
                    }
                }
            }
            It 'should return the not met for non compatible pwsh versions' {
                Test-ALZRequirement | Should -BeExactly "ALZ requirements are not met."
            }
        }
        Context 'Incompatible Powershell version 7.0' {
            BeforeEach {
                Mock -CommandName Get-PSVersion -MockWith {
                    [PSCustomObject]@{
                        PSVersion = [PSCustomObject]@{
                            Major = 7
                            Minor = 0
                        }
                    }
                }
            }
            It 'should return the not met for non compatible pwsh versions' {
                Test-ALZRequirement | Should -BeExactly "ALZ requirements are not met."
            }
        }
        Context 'Git not installed' {
            BeforeEach {
                Mock -CommandName Get-Command -MockWith {
                    $null
                }
            }
            It 'should return the not met for no git instalation' {
                Test-ALZRequirement | Should -BeExactly "ALZ requirements are not met."
            }
        }
        Context 'Success' {

            BeforeEach {
            }

            It 'should return the expected results' {
                Test-ALZRequirement | Should -BeExactly "ALZ requirements are met."
            }

        }
    }
}
