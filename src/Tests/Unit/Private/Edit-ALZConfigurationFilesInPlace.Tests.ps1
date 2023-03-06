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
    BeforeAll {
        $defaultConfig =  @(
        @{
            description  = "The prefix that will be added to all resources created by this deployment."
            names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
            value        = "test"
            defaultValue = "alz"
        },
        @{
            description  = "The suffix that will be added to all resources created by this deployment."
            names        = @("parTopLevelManagementGroupSuffix")
            value        = ""
            defaultValue = "bla"
        },
        @{
            description   = "Deployment location."
            name          = @("parLocation")
            allowedValues = @('ukwest', 'eastus')
            value         = "eastus"
        }
    )
    }
    Describe 'Edit-ALZConfigurationFilesInPlace Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'EditConfigFiles correctly' {
            BeforeEach {
                Mock -CommandName Get-ChildItem -MockWith {
                    @(
                        [PSCustomObject]@{
                            FullName = 'test1.parameters.json'
                        },
                        [PSCustomObject]@{
                            FullName = 'test2.parameters.json'
                        }
                    )
                }
                Mock -CommandName Get-Content -ParameterFilter { $Path -eq 'test1.parameters.json' } -MockWith {
                    '{
                        "parameters": {
                            "parTopLevelManagementGroupPrefix": {
                                "value": "alz"
                            },
                            "parCompanyPrefix": {
                                "value": "alz"
                            }
                        }
                    }'
                }
                Mock -CommandName Get-Content -ParameterFilter { $Path -eq 'test2.parameters.json' } -MockWith {
                    '{
                        "parameters": {
                            "parTopLevelManagementGroupSuffix": {
                                "value": ""
                            },
                            "parLocation": {
                                "value": ""
                            }
                        }
                    }'
                }
            }
            It 'Files shuld be changed correctly' {
                Edit-ALZConfigurationFilesInPlace  -alzBicepRoot '.' -configuration $defaultConfig
                # Assert that the file was wirte back with the new values
                Assert-MockCalled -CommandName Set-Content -Exactly 2 -Scope It
                Assert-MockCalled -CommandName Set-Content -ParameterFilter { $Path -eq 'test1.parameters.json' } -Scope It
                Assert-MockCalled -CommandName Set-Content -ParameterFilter { $Path -eq 'test2.parameters.json' } -Scope It
                Assert-MockCalled -CommandName Set-Content -ParameterFilter { $Value -eq '{
                        "parameters": {
                            "parTopLevelManagementGroupPrefix": {
                                "value": "test"
                            },
                            "parCompanyPrefix": {
                                "value": "test"
                            }
                        }
                    }' } -Scope It
                Assert-MockCalled -CommandName Set-Content -ParameterFilter { $Value -eq '{
                        "parameters": {
                            "parTopLevelManagementGroupSuffix": {
                                "value": "bla"
                            },
                            "parLocation": {
                                "value": "eastus"
                            }
                        }
                    }' } -Scope It
            }
        }
    }
}
