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
    Describe 'Set-ComputedConfiguration Private Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Set-ComputedConfiguration should update the configuration correctly' {
            It 'Handles Computed values correctly.' {
                $configuration = [pscustomobject]@{
                    Setting1 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting1"
                                Destination = "Environment"
                            })
                        Value   = "Test"
                    }
                    Setting2 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting2"
                                Destination = "Environment"
                            })
                        Source  = "calculated"
                        Value   = "{%Setting1%}"
                    }
                }

                Set-ComputedConfiguration -configuration $configuration
                $configuration.Setting2.Value | Should -BeExactly "Test"
            }

            It 'Computed, Processed array values replace values correctly' {
                $configuration = [pscustomobject]@{
                    Nested = [pscustomobject]@{
                        Source      = "calculated"
                        Description = "A Test Value"
                        Process     = '@($args | Select-Object -Unique)'
                        Value       = @(
                            "1",
                            "1",
                            "3"
                        )
                        Targets     = @(
                            [pscustomobject]@{
                                Name        = "parValue.value"
                                Destination = "Parameters"
                            })
                    }
                }

                Set-ComputedConfiguration -configuration $configuration
                $configuration.Nested.Value | Should -BeExactly @("1", "3")
            }

            It 'Computed, Processed array values replace values correctly in a case insensitive deduplication.' {
                $configuration = [pscustomobject]@{
                    Nested = [pscustomobject]@{
                        Source      = "calculated"
                        Description = "A Test Value"
                        Process     = '@($args | ForEach-Object { $_.ToLower() } | Select-Object -Unique)'
                        Value       = @(
                            "A",
                            "a",
                            "A",
                            "a"
                        )
                        Targets     = @(
                            [pscustomobject]@{
                                Name        = "parValue.value"
                                Destination = "Parameters"
                            })
                    }
                }

                Set-ComputedConfiguration -configuration $configuration
                $configuration.Nested.Value | Should -BeExactly @("a")
            }

            It 'Computed, Processed array values replace values correctly and keep array type when only one item remains.' {
                $configuration = [pscustomobject]@{
                    Nested = [pscustomobject]@{
                        Source      = "calculated"
                        Description = "A Test Value"
                        Process     = '@($args | Select-Object -Unique)'
                        Value       = @(
                            "1",
                            "1",
                            "1"
                        )
                        Targets     = @(
                            [pscustomobject]@{
                                Name        = "parValue.value"
                                Destination = "Parameters"
                            })
                    }
                }

                Set-ComputedConfiguration -configuration $configuration
                $configuration.Nested.Value | Should -BeExactly @("1")
            }

            It 'Computed, Processed values replace values correctly' {
                $configuration = [pscustomobject]@{
                    Nested = [pscustomobject]@{
                        Source      = "calculated"
                        Description = "A Test Value"
                        Process     = '($args[0] -eq "eastus") ? "eastus2" : ($args[0] -eq "eastus2") ? "eastus" : $args[0]'
                        Value       = "eastus"
                        Targets     = @(
                            [pscustomobject]@{
                                Name        = "parValue.value"
                                Destination = "Parameters"
                            })
                    }
                }

                Set-ComputedConfiguration -configuration $configuration
                $configuration.Nested.Value | Should -BeExactly "eastus2"
            }

            It 'Computed, Processed values replace values correctly' {
                $configuration = [pscustomobject]@{
                    Nested = [pscustomobject]@{
                        Source      = "calculated"
                        Description = "A Test Value"
                        Process     = '($args[0] -eq "goodbye") ? "Hello" : "Goodbye"'
                        Value       = "goodbye"
                        Targets     = @(
                            [pscustomobject]@{
                                Name        = "parValue.value"
                                Destination = "Parameters"
                            })
                    }
                }

                Set-ComputedConfiguration -configuration $configuration
                $configuration.Nested.Value | Should -BeExactly "Hello"
            }
        }
    }
}
