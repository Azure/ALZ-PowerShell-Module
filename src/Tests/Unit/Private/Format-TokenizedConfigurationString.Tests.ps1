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
    Describe 'Format-TokenizedConfigurationString tests ' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Replace the specified tokens with values in the configuration object.' {
            BeforeEach {
            }
            It 'When there is one token to replace.' {
                $configuration = [pscustomobject]@{
                    Setting1 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting1"
                                Destination = "Environment"
                            })
                        Value   = "Test1"
                    }
                    Setting2 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting2"
                                Destination = "Parameters"
                            })
                        Value   = "Test2"
                    }
                }

                Format-TokenizedConfigurationString "{%Setting1%}" $configuration | Should -Be "Test1"
            }

            It 'When there are two tokens to replace.' {

                $configuration = [pscustomobject]@{
                    Setting1 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting1"
                                Destination = "Environment"
                            })
                        Value   = "Test1"
                    }
                    Setting2 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting2"
                                Destination = "Parameters"
                            })
                        Value   = "Test2"
                    }
                }

                Format-TokenizedConfigurationString "{%Setting1%}/{%Setting2%}" $configuration | Should -Be "Test1/Test2"
            }

            It 'When the token is not found.' {
                $configuration = [pscustomobject]@{
                    Setting1 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting1"
                                Destination = "Environment"
                            })
                        Value   = "Test1"
                    }
                    Setting2 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting2"
                                Destination = "Parameters"
                            })
                        Value   = "Test2"
                    }
                }

                Format-TokenizedConfigurationString "{%DoesntMatch%}" $configuration | Should -Be "{%DoesntMatch%}"
            }

            It 'When the token is repeated.' {

                $configuration = [pscustomobject]@{
                    Setting1 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting1"
                                Destination = "Environment"
                            })
                        Value   = "Test1"
                    }
                    Setting2 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting2"
                                Destination = "Parameters"
                            })
                        Value   = "Test2"
                    }
                }

                Format-TokenizedConfigurationString "{%Setting1%}/{%Setting1%}/{%Setting1%}/{%Setting1%}" $configuration | Should -Be "Test1/Test1/Test1/Test1"
            }
        }
    }
}
