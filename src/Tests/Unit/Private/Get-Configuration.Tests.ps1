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
    Describe 'Get-Configuration Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Create the correct folders for the environment' {
            BeforeEach {
                Mock -CommandName Get-Content -MockWith {
                    '
                    {
                        "Prefix": {
                            "Type": "UserInput",
                            "Description": "The prefix that will be added to all resources created by this deployment. (e.g. alz)",
                            "Targets": [
                            {
                                "Name": "parTopLevelManagementGroupPrefix",
                                "Destination": "Parameters"
                            },
                            {
                                "Name": "parCompanyPrefix",
                                "Destination": "Parameters"
                            },
                            {
                                "Name": "parTargetManagementGroupId",
                                "Destination": "Parameters"
                            },
                            {
                                "Name": "parAssignableScopeManagementGroupId",
                                "Destination": "Parameters"
                            }
                            ],
                            "Value": "",
                            "DefaultValue": "alz",
                            "Valid": "^[a-zA-Z]{3,5}$"
                        },
                        "Suffix": {
                            "Type": "UserInput",
                            "Description": "The suffix that will be added to all resources created by this deployment. (e.g. test)",
                            "Targets": [
                            {
                                "Name": "parTopLevelManagementGroupSuffix",
                                "Destination": "Parameters"
                            }
                            ],
                            "Value": "",
                            "DefaultValue": "",
                            "Valid": "^[a-zA-Z]{0,5}$"
                        },
                        "Location": {
                            "Type": "UserInput",
                            "Description": "Deployment location.",
                            "Value": "",
                            "Targets": [
                                {
                                    "Name": "parLocation",
                                    "Destination": "Parameters"
                                },
                                {
                                    "Name": "parAutomationAccountLocation",
                                    "Destination": "Parameters"
                                },
                                {
                                    "Name": "parLogAnalyticsWorkspaceLocation",
                                    "Destination": "Parameters"
                                }
                            ],
                            "AllowedValues": [
                                "eastus",
                                "ukwest"
                            ]
                        },
                        "Environment": {
                            "Type": "UserInput",
                            "Description": "The Type of environment that will be created. (e.g. dev, test, qa, staging, prod)",
                            "Targets": [
                                {
                                    "Name": "parEnvironment",
                                    "Destination": "Parameters"
                                }
                            ],
                            "Value": "",
                            "DefaultValue": "prod",
                            "Valid": "^[a-zA-Z0-9]{2,10}$"
                        },
                    }'
                }
            }
            It 'configuration loads correctly.' {
                $content = Get-Configuration
                $content.Prefix.Value | Should -Be ''
                $content.Prefix.DefaultValue | Should -Be 'alz'
                $content.Prefix.Description | Should -Be "The prefix that will be added to all resources created by this deployment. (e.g. alz)"

                $content.Suffix.Value | Should -Be ''
                $content.Suffix.DefaultValue | Should -Be ''
                $content.Suffix.Description | Should -Be "The suffix that will be added to all resources created by this deployment. (e.g. test)"

                $content.Location.Value | Should -Be ''
                $content.Location.Description | Should -Be 'Deployment location.'
                $content.Location.AllowedValues | Should -Be @('eastus', 'ukwest')

                $content.Environment.Value | Should -Be ''
                $content.Environment.Description | Should -Be "The type of environment that will be created. (e.g. dev, test, qa, staging, prod)"
                $content.Environment.DefaultValue | Should -Be 'prod'
            }

            It 'Throws for unsupported Terraform IAC' {
                { Get-Configuration -alzIacProvider "terraform" } | Should -Throw -ExpectedMessage "Terraform is not yet supported."
            }
        }
    }
}
