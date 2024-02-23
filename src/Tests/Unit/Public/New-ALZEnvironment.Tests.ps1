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

                Mock -CommandName Get-ALZConfig -MockWith {
                    @{
                        "module_url"   = "test"
                        "version"      = "v1.0.0"
                        "config_files" = @(
                            @{
                                "source"      = "a"
                                "destination" = "b"
                            }
                        )
                        "cicd"         = @{
                            "azuredevops" = @(
                                @{
                                    "source"      = "a"
                                    "destination" = "b"
                                }
                            )
                            "github"      = @(
                                @{
                                    "source"      = "a"
                                    "destination" = "b"
                                }
                            )
                        }
                        "parameters"   = @{
                            "test" = @{
                                "type" = "string"
                            }
                        }
                    }
                }

                Mock -CommandName Get-GithubRelease -MockWith { $("v0.0.1") }

                Mock -CommandName Test-ALZGitRepository -MockWith { $false }

                Mock -CommandName Copy-ALZParametersFile -MockWith { }

                Mock -CommandName Write-InformationColored

                Mock -CommandName Get-HCLParserTool -MockWith { "test" }

                Mock -CommandName Get-TerraformTool -MockWith { }

                Mock -CommandName Convert-HCLVariablesToUserInputConfig -MockWith {
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

                Mock -CommandName Write-TfvarsFile -MockWith { }

                Mock -CommandName Write-ConfigurationCache -MockWith { }

                Mock -CommandName Invoke-Terraform -MockWith { }

                Mock -CommandName Import-SubscriptionData -MockWith { }

                Mock -CommandName Import-StarterPath -MockWith {}

                Mock -CommandName Invoke-Upgrade -MockWith { }

                Mock -CommandName Get-TerraformTool -MockWith {}
            }

            It 'should call the correct functions for bicep legacy module configuration' {
                New-ALZEnvironment -i "bicep" -c "github"
                Assert-MockCalled -CommandName Get-GithubRelease -Exactly 1
                Assert-MockCalled -CommandName Edit-ALZConfigurationFilesInPlace -Exactly 1
            }

            It 'should call the correct functions for bicep modern module configuration' {
                New-ALZEnvironment -i "bicep" -c "github"
                #Assert-MockCalled -CommandName Get-GithubRelease -Exactly 2
                Assert-MockCalled -CommandName Edit-ALZConfigurationFilesInPlace -Exactly 1
            }

            It 'should call the correct functions for terraform module configuration' {
                New-ALZEnvironment -i "terraform" -c "github"
                #Assert-MockCalled -CommandName Get-GithubRelease -Exactly 2
                #Assert-MockCalled -CommandName Invoke-Terraform -Exactly 1
            }
        }
    }
}
