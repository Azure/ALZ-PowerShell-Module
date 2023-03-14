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
    Describe 'Request-ConfigurationValue Public Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'User inputs requested value' {
            BeforeEach {
                Mock -CommandName Write-InformationColored -MockWith {
                    $null
                }

                Mock -CommandName Read-Host -MockWith {
                    "user input value"
                }
            }
            It 'Prompt the user for configuration with a default value.' {
                $configValue = @{
                    Description  = "The prefix that will be added to all resources created by this deployment."
                    Names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    Value        = ""
                    DefaultValue = "alz"
                }

                Request-ConfigurationValue -configName "prefix" -configValue $configValue

                Assert-MockCalled -CommandName Write-InformationColored -Times 3

                $configValue.Value | Should -BeExactly "user input value"
            }

            It 'Prompt the user with warning text if no value is specified and no default value is present.' {
                Mock -CommandName Read-Host -MockWith {
                    ""
                }

                $configValue = @{
                    Description = "The prefix that will be added to all resources created by this deployment."
                    Names       = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    Value       = ""
                }

                Request-ConfigurationValue -configName "prefix" -configValue $configValue -withRetries $false

                Should -Invoke -CommandName Write-InformationColored -ParameterFilter { $ForegroundColor -eq "Red" } -Scope It

                $configValue.Value | Should -BeExactly ""
            }

            It 'Prompt the user with warning text when an invalid value is specified and leave the existing value unchanged.' {
                $configValue = @{
                    Description  = "The prefix that will be added to all resources created by this deployment."
                    Names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    Value        = ""
                    DefaultValue = "alz"
                    Valid        = "^[a-zA-Z]{3,5}$"
                }

                Request-ConfigurationValue -configName "prefix" -configValue $configValue -withRetries $false

                Should -Invoke -CommandName Write-InformationColored -ParameterFilter { $ForegroundColor -eq "Red" } -Scope It
                $configValue.Value | Should -BeExactly ""
            }

            It 'Prompt the user with warning text when a value is specified which isnt in the allowed list and leave the existing value unchanged.' {
                Mock -CommandName Read-Host -MockWith {
                    "notinthelist"
                }

                $configValue = @{
                    Description   = "The prefix that will be added to all resources created by this deployment."
                    Names         = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    Value         = ""
                    AllowedValues = @("alz", "slz")
                }
                Request-ConfigurationValue -configName "prefix" -configValue $configValue -withRetries $false

                Should -Invoke -CommandName Write-InformationColored -ParameterFilter { $ForegroundColor -eq "Red" } -Scope It
                $configValue.Value | Should -BeExactly ""
            }
        }
    }
}
