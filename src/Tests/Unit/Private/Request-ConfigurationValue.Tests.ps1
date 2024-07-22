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

                Should -Invoke -CommandName Write-InformationColored -Times 3 -Exactly

                $configValue.Value | Should -BeExactly "user input value"
            }

            It 'Prompt the user for configuration and providing no value selects the default value.' {
                Mock -CommandName Read-Host -MockWith {
                    ""
                }

                $configValue = @{
                    Description  = "The prefix that will be added to all resources created by this deployment."
                    Names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    Value        = ""
                    DefaultValue = "alz"
                }

                Request-ConfigurationValue -configName "prefix" -configValue $configValue

                Should -Invoke -CommandName Write-InformationColored -Times 3 -Exactly

                $configValue.Value | Should -BeExactly "alz"
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

            It 'Prompt the user with warning text when an invalid value is specified.' {
                $configValue = @{
                    Description  = "The prefix that will be added to all resources created by this deployment."
                    Names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    Value        = ""
                    DefaultValue = "alz"
                    Valid        = "^[a-zA-Z0-9]{2,10}(-[a-zA-Z0-9]{2,10})?$"
                }

                Request-ConfigurationValue -configName "prefix" -configValue $configValue -withRetries $false

                Should -Invoke -CommandName Write-InformationColored -ParameterFilter { $ForegroundColor -eq "Red" } -Scope It
            }

            It 'Prompt the user with warning text when a value is specified which isnt in the allowed list.' {
                Mock -CommandName Read-Host -MockWith {
                    "notinthelist"
                }

                $configValue = @{
                    Description   = "The prefix that will be added to all resources created by this deployment."
                    Names         = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    Value         = ""
                    AllowedValues = @{
                        Values = @("alz", "slz")
                    }
                }
                Request-ConfigurationValue -configName "prefix" -configValue $configValue -withRetries $false

                Should -Invoke -CommandName Write-InformationColored -ParameterFilter { $ForegroundColor -eq "Red" } -Scope It
            }

            It 'Prompt the user with warning text when a value is specified which isnt in the allowed list for a list(string).' {
                Mock -CommandName Read-Host -MockWith {
                    "alz,notinthelist"
                }

                $configValue = @{
                    Description   = "The prefix that will be added to all resources created by this deployment."
                    Names         = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    DataType      = "list(string)"
                    Value         = ""
                    AllowedValues = @{
                        Values = @("alz", "slz")
                    }
                }
                Request-ConfigurationValue -configName "prefix" -configValue $configValue -withRetries $false

                Should -Invoke -CommandName Write-InformationColored -ParameterFilter { $ForegroundColor -eq "Red" } -Scope It
            }

            It 'Prompt user with a calculated list of AllowedValues' {
                Mock -CommandName Read-Host -MockWith {
                    "l"
                }

                $configValue = @{
                    Description   = "The prefix that will be added to all resources created by this deployment."
                    Names         = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    Value         = ""
                    AllowedValues = @{
                        Type = "PSScript"
                        Values = @()
                        Script = '"h e l l o" -split " "'
                        Display = $true
                        Description = "A collection of values returned by PS Script"
                    }
                }
                Request-ConfigurationValue -configName "calculated" -configValue $configValue -withRetries $false

                Should -Invoke -CommandName Write-InformationColored -Times 5 -Exactly
                $configValue.Value | Should -BeExactly "l"
            }

            It 'Do not display the calculated list of AllowedValues if Display is false' {
                Mock -CommandName Read-Host -MockWith {
                    "l"
                }

                $configValue = @{
                    Description   = "The prefix that will be added to all resources created by this deployment."
                    Names         = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    Value         = ""
                    AllowedValues = @{
                        Type = "PSScript"
                        Values = @()
                        Script = '"h e l l o" -split " "'
                        Display = $false
                        Description = "A collection of values returned by PS Script"
                    }
                }
                Request-ConfigurationValue -configName "calculated" -configValue $configValue -withRetries $false

                Should -Invoke -CommandName Write-InformationColored -Times 4 -Exactly
                $configValue.Value | Should -BeExactly "l"
            }
        }
    }
}
