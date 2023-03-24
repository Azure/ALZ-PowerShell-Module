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
        $testFile1Name = "test.parameters.all.json"

        Mock -CommandName Out-File -MockWith {
            Write-InformationColored "Out-File was called with $FilePath and $InputObject" -ForegroundColor Yellow -InformationAction Continue
        }

        Mock -CommandName Get-ChildItem -ParameterFilter { $Path -match 'config$' } -MockWith {
            @(
                [PSCustomObject]@{
                    FullName = $testFile1Name
                }
            )
        }

        function Initialize-TestConfiguration {
            param(
                [Parameter(Mandatory = $true)]
                [string]$configTarget,

                [Parameter(Mandatory = $true)]
                [string]$withValue
                )

                return [pscustomobject]@{
                    Nested     = [pscustomobject]@{
                        Type        = "Computed"
                        Description = "A Test Value"
                        Value       = $withValue
                        Targets     = @(
                            [pscustomobject]@{
                                Name        = $configTarget
                                Destination = "Parameters"
                            })
                    }
                }
        }

        function Format-ExpectedResult {
            param(
                [Parameter(Mandatory = $true)]
                [string]$expectedJson
            )

            # Get the formatting correct by using the same JSON formatter.
            return ConvertFrom-Json -InputObject $expectedJson -AsHashtable | ConvertTo-Json -Depth 10
        }
    }
    Describe 'Edit-ALZConfigurationFilesInPlace Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Edit-ALZConfigurationFilesInPlace should replace the parameters correctly' {

            # It 'Should replace array values correctly (JSON Object)' {
            #     $config = Initialize-TestConfiguration -configTarget  "parValue.value.[0]" -withValue "value"

            #     $fileContent = '{
            #         "parameters": {
            #             "parValue": {
            #                 "value": ["replace_me", "dont_replace_me"]
            #             }
            #         }
            #     }'

            #     $expectedContent = '{
            #         "parameters": {
            #             "parValue": {
            #                 "value":  ["value", , "dont_replace_me"]
            #             }
            #         }
            #     }'

            #     Mock -CommandName Get-Content -ParameterFilter { $Path -eq $testFile1Name } -MockWith {
            #         $fileContent
            #     }

            #     $expectedContent = Format-ExpectedResult -expectedJson $expectedContent

            #     Edit-ALZConfigurationFilesInPlace  -alzEnvironmentDestination '.' -configuration $config

            #     Should -Invoke -CommandName Out-File `
            #         -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
            #         -Scope It
            # }

            It 'Should replace simple values correctly (Bicep Object)' {
                $config = Initialize-TestConfiguration -configTarget  "parValue.value" -withValue "value"

                $fileContent = '{
                    "parameters": {
                        "parValue": {
                            "value": "replace_me"
                        }
                    }
                }'

                $expectedContent = '{
                    "parameters": {
                        "parValue": {
                            "value": "value"
                        }
                    }
                }'

                Mock -CommandName Get-Content -ParameterFilter { $Path -eq $testFile1Name } -MockWith {
                    $fileContent
                }

                $expectedContent = Format-ExpectedResult -expectedJson $expectedContent

                Edit-ALZConfigurationFilesInPlace  -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
                    -Scope It
            }

            It "Should replace 'Parameter' destinations to nested array objects correctly" {
                $config = Initialize-TestConfiguration -configTarget  "parNested.value.[0].parChildValue.value" -withValue "nested"

                $fileContent = '{
                    "parameters": {
                        "parNested": {
                            "value": [{
                                "parChildValue": {
                                    "value": "replace_me"
                                }
                            }]
                        }
                    }
                }'

                $expectedContent = '{
                    "parameters": {
                        "parNested": {
                            "value": [{
                                "parChildValue": {
                                    "value": "nested"
                                }
                            }]
                        }
                    }
                }'

                Mock -CommandName Get-Content -ParameterFilter { $Path -eq $testFile1Name } -MockWith {
                    $fileContent
                }

                $expectedContent = Format-ExpectedResult -expectedJson $expectedContent

                Edit-ALZConfigurationFilesInPlace  -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
                    -Scope It
            }

            It 'Should replace nested values correctly (Plain JSON Object)' {
                $config = Initialize-TestConfiguration -configTarget  "parNested.value.parChildValue" -withValue "nested"

                $fileContent = '{
                    "parameters": {
                        "parNested": {
                            "value": {
                                "parChildValue": "replace_me"
                            }
                        }
                    }
                }'

                $expectedContent = '{
                    "parameters": {
                        "parNested": {
                            "value": {
                                "parChildValue": "nested"
                            }
                        }
                    }
                }'

                Mock -CommandName Get-Content -ParameterFilter { $Path -eq $testFile1Name } -MockWith {
                    $fileContent
                }

                $expectedContent = Format-ExpectedResult -expectedJson $expectedContent

                Edit-ALZConfigurationFilesInPlace  -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
                    -Scope It
            }

            It 'Should replace nested values correctly (Bicep Object)' {
                $config = Initialize-TestConfiguration -configTarget  "parNested.value.parChildValue.value" -withValue "nested"

                $fileContent = '{
                    "parameters": {
                        "parNested": {
                            "value": {
                                "parChildValue": {
                                    "value": "replace_me"
                                }
                            }
                        }
                    }
                }'

                $expectedContent = '{
                    "parameters": {
                        "parNested": {
                            "value": {
                                "parChildValue": {
                                    "value": "nested"
                                }
                            }
                        }
                    }
                }'

                Mock -CommandName Get-Content -ParameterFilter { $Path -eq $testFile1Name } -MockWith {
                    $fileContent
                }

                $expectedContent = Format-ExpectedResult -expectedJson $expectedContent

                Edit-ALZConfigurationFilesInPlace  -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
                    -Scope It
            }

            It 'Multiple files with multiple values should be changed correctly' {
                $defaultConfig = [pscustomobject]@{
                    Prefix      = [pscustomobject]@{
                        Description  = "The prefix that will be added to all resources created by this deployment."
                        Targets      = @(
                            [pscustomobject]@{
                                Name        = "parTopLevelManagementGroupPrefix.value"
                                Destination = "Parameters"
                            },
                            [pscustomobject]@{
                                Name        = "parCompanyPrefix.value"
                                Destination = "Parameters"
                            })
                        Value        = "test"
                        DefaultValue = "alz"
                    }
                    Suffix      = [pscustomobject]@{
                        Description  = "The suffix that will be added to all resources created by this deployment."
                        Targets      = @(
                            [pscustomobject]@{
                                Name        = "parTopLevelManagementGroupSuffix.value"
                                Destination = "Parameters"
                            })
                        Value        = "bla"
                        DefaultValue = ""
                    }
                    Location    = [pscustomobject]@{
                        Description   = "Deployment location."
                        Targets       = @(
                            [pscustomobject]@{
                                Name        = "parLocation.value"
                                Destination = "Parameters"
                            })
                        AllowedValues = @('ukwest', '')
                        Value         = "eastus"
                    }
                    Environment = [pscustomobject]@{
                        Description  = "The type of environment that will be created . Example: dev, test, qa, staging, prod"
                        Targets      = @(
                            [pscustomobject]@{
                                Name        = "parEnvironment.value"
                                Destination = "Parameters"
                            })
                        DefaultValue = 'prod'
                        Value        = "dev"
                    }
                    Logging     = [pscustomobject]@{
                        Type        = "Computed"
                        Description = "The type of environment that will be created . Example: dev, test, qa, staging, prod"
                        Value       = "logs/{%Environment%}/{%Location%}"
                        Targets     = @(
                            [pscustomobject]@{
                                Name        = "parLogging.value"
                                Destination = "Parameters"
                            })
                    }
                }
                $firstFileContent = '{
                    "parameters": {
                        "parCompanyPrefix": {
                            "value": ""
                        },
                        "parTopLevelManagementGroupPrefix": {
                            "value": ""
                        },
                        "parLogging" : {
                            "value": ""
                        }
                    }
                }'
                $secondFileContent = '{
                    "parameters": {
                        "parTopLevelManagementGroupSuffix": {
                            "value": ""
                        },
                        "parLocation": {
                            "value": ""
                        }
                    }
                }'

                Mock -CommandName Get-ChildItem -ParameterFilter { $Path -match 'config$' } -MockWith {
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
                    $firstFileContent
                }
                Mock -CommandName Get-Content -ParameterFilter { $Path -eq 'test2.parameters.json' } -MockWith {
                    $secondFileContent
                }

                Edit-ALZConfigurationFilesInPlace  -alzEnvironmentDestination '.' -configuration $defaultConfig

                Should -Invoke -CommandName Out-File -Scope It -Times 2

                # Assert that the file was written back with the new values
                $contentAfterParsing = ConvertFrom-Json -InputObject $firstFileContent -AsHashtable
                $contentAfterParsing.parameters.parTopLevelManagementGroupPrefix.value = 'test'
                $contentAfterParsing.parameters.parCompanyPrefix.value = 'test'
                $contentAfterParsing.parameters.parLogging.value = "logs/dev/eastus"
                # $contentAfterParsing.parameters.parNested.value.parChildValue.value = "nested"
                $contentStringAfterParsing = ConvertTo-Json -InputObject $contentAfterParsing
                Write-InformationColored $contentStringAfterParsing -ForegroundColor Yellow -InformationAction Continue
                Should -Invoke -CommandName Out-File -ParameterFilter { $FilePath -eq "test1.parameters.json" -and $InputObject -eq $contentStringAfterParsing } -Scope It

                $contentAfterParsing = ConvertFrom-Json -InputObject $secondFileContent -AsHashtable
                $contentAfterParsing.parameters.parTopLevelManagementGroupSuffix.value = 'bla'
                $contentAfterParsing.parameters.parLocation.value = 'eastus'
                $contentStringAfterParsing = ConvertTo-Json -InputObject $contentAfterParsing
                Write-InformationColored $contentStringAfterParsing -ForegroundColor Yellow -InformationAction Continue
                Should -Invoke -CommandName Out-File -ParameterFilter { $FilePath -eq "test2.parameters.json" -and $InputObject -eq $contentStringAfterParsing } -Scope It
            }
        }
    }
}
