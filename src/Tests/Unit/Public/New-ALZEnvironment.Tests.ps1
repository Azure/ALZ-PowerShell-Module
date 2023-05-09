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
    Describe 'New-ALZEnvironment Public Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Error' {
        }
        Context 'Success' {
            BeforeEach {
                Mock -CommandName Request-ALZEnvironmentConfig -MockWith {
                    @(
                        @{
                            "description"  = "Test configuration 1"
                            "names"        = @("value1", "value2")
                            "defaultValue" = "default"
                            "value"        = "value"
                        },
                        @{
                            "description"  = "Test configuration 2"
                            "names"        = @("value1")
                            "defaultValue" = "default"
                            "value"        = "value"
                        }
                    )
                }

                Mock -CommandName Edit-ALZConfigurationFilesInPlace
                Mock -CommandName Build-ALZDeploymentEnvFile

                Mock -CommandName New-ALZDirectoryEnvironment -MockWith { }

                Mock -CommandName Copy-Item -MockWith { }

                Mock -CommandName Get-ALZBicepConfig -MockWith {
                    @{
                        "module_url"   = "test"
                        "version"      = "v1.0.0"
                        "config_files" = @(
                            @{
                                "source"      = "a"
                                "destination" = "b"
                            }
                        )
                        "parameters"   = @{
                            "test" = @{
                                "type" = "string"
                            }
                        }
                    }
                }

                Mock -CommandName Get-ALZGithubRelease -MockWith { }

                Mock -CommandName Test-ALZGitRepository -MockWith { $false }

                Mock -CommandName Copy-ALZParametersFile -MockWith { }

                Mock -CommandName Write-InformationColored

            }

            It 'should return the output directory on completion' {
                New-ALZEnvironment
                Assert-MockCalled -CommandName Edit-ALZConfigurationFilesInPlace -Exactly 1
            }

            It 'Warns if the unsupported Terraform IAC is specified.' {
                New-ALZEnvironment -alzIacProvider "terraform"

                Should -Invoke -CommandName Write-InformationColored -ParameterFilter { $ForegroundColor -eq "Red" } -Scope It
            }
        }
    }
}
