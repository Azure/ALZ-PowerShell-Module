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
                Mock -CommandName Set-Config -MockWith {
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

                Mock -CommandName Copy-Item -MockWith { }

                Mock -CommandName Get-ALZConfig -MockWith {
                    @{
                        "module_url"   = "test"
                        "version"      = "v1.0.0"
                        "deployment_files" = @(
                            @{
                                "displayName"                      = "Management Groups Deployment"
                                "templateFilePath"                 = "./infra-as-code/bicep/modules/managementGroups/managementGroupsScopeEscape.bicep"
                                "templateParametersFilePath"       = "./config/custom-parameters/managementGroups.parameters.all.json"
                                "templateParametersSourceFilePath" = "./infra-as-code/bicep/modules/managementGroups/parameters/managementGroups.parameters.all.json"
                                "deploymentType"                   = "managementGroup"
                            }
                        )
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

                Mock -CommandName Write-InformationColored

                Mock -CommandName Get-HCLParserTool -MockWith { "test" }

                Mock -CommandName Get-TerraformTool -MockWith { }

                Mock -CommandName Convert-HCLVariablesToInputConfig -MockWith {
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

                Mock -CommandName Invoke-Terraform -MockWith { }

                Mock -CommandName Invoke-Upgrade -MockWith { }

                Mock -CommandName Invoke-FullUpgrade -MockWith { }

                Mock -CommandName Get-TerraformTool -MockWith {}

                Mock -CommandName New-FolderStructure -MockWith {}

                Mock -CommandName New-ModuleSetup -MockWith {
                    @{
                        "version" = "v0.0.1"
                        "path"    = "./example/example"
                    }
                }

                Mock -CommandName Get-BootstrapAndStarterConfig -MockWith {
                    @{
                        "hasStarterModule" = $true
                        "validationConfig" = @{
                            "azure_location" = @{
                                "AllowedValues" = @{
                                    "Values" = @( "uksouth", "ukwest" )
                                }
                            }
                        }
                    }
                }

                Mock -CommandName New-Bootstrap -MockWith {}

                Mock -CommandName Get-AzureRegionData -MockWith {
                    @{
                        "uksouth" = @{
                            "display_name" = "UK South"
                            "zone" = @( "1", "2", "3" )
                        }
                    }
                }
            }

            It 'should call the correct functions for bicep module configuration' {
                Deploy-Accelerator -i "bicep" -b "github" -inputs "example.yml"
                Assert-MockCalled -CommandName Get-BootstrapAndStarterConfig -Exactly 1
                Assert-MockCalled -CommandName New-ModuleSetup -Exactly 2
            }

            It 'should call the correct functions for terraform module configuration' {
                Deploy-Accelerator -i "terraform" -b "github" -inputs "example.yml"
                Assert-MockCalled -CommandName Get-BootstrapAndStarterConfig -Exactly 1
                Assert-MockCalled -CommandName New-Bootstrap -Exactly 1
                Assert-MockCalled -CommandName New-ModuleSetup -Exactly 2
            }
        }
    }
}
