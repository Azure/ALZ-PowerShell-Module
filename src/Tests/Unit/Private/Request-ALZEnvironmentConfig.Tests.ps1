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
    Describe 'Request-ALZEnvironmentConfig Private Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Request-ALZEnvironmentConfig should request CLI input for configuration.' {
            It 'Based on the configuration object' {

                Mock -CommandName Get-Configuration -MockWith {
                    [pscustomobject]@{
                        Setting1 = [pscustomobject]@{
                            Type           = "UserInput"
                            ForEnvironment = $true
                            Value          = "Test1"
                        }
                        Setting2 = [pscustomobject]@{
                            Type           = "UserInput"
                            ForEnvironment = $true
                            Value          = "Test2"
                        }
                    }
                }

                Mock -CommandName Request-ConfigurationValue

                Request-ALZEnvironmentConfig -alzIacProvider "bicep" -alzEnvironmentDestination "." -alzBicepVersion "v0.13.0"

                Should -Invoke Request-ConfigurationValue -Scope It -Times 2 -Exactly
            }

            It 'Throws if the unsupported Terraform IAC is specified.' {
                { Request-ALZEnvironmentConfig -alzIacProvider "terraform" -alzEnvironmentDestination "." -alzBicepVersion "v0.13.0" } | Should -Throw -ExpectedMessage "Terraform is not yet supported."
            }
        }
    }
}