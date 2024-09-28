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
            $config = [pscustomobject]@{
                Nested = [pscustomobject]@{
                    Source      = "calculated"
                    Description = "A Test Value"
                    Value       = $withValue
                    Targets     = @(
                        [pscustomobject]@{
                            Name        = $configTarget
                            Destination = "Parameters"
                        })
                }
            }

            return $config
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

            It 'Should replace array values correctly (JSON Object) - first' {
                $config = Initialize-TestConfiguration -configTarget "parValue.value.[0]" -withValue "value"

                $fileContent = '{
                    "parameters": {
                        "parValue": {
                            "value": [
                                "replace_me",
                                "dont_replace_me"
                            ]
                        }
                    }
                }'

                $expectedContent = '{
                    "parameters": {
                        "parValue": {
                            "value":  [
                                "value",
                                "dont_replace_me"
                            ]
                        }
                    }
                }'

                Mock -CommandName Get-Content -ParameterFilter { $Path -eq $testFile1Name } -MockWith {
                    $fileContent
                }

                $expectedContent = Format-ExpectedResult -expectedJson $expectedContent

                Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
                    -Scope It
            }

            It 'Should replace array an entire array correctly (JSON Object)' {
                $config = Initialize-TestConfiguration -configTarget "parValue.value.[1]" -withValue "value"

                $fileContent = '{
                    "parameters": {
                        "parValue": {
                            "value": [
                                "dont_replace_me",
                                "replace_me"
                            ]
                        }
                    }
                }'

                $expectedContent = '{
                    "parameters": {
                        "parValue": {
                            "value":  [
                                "dont_replace_me",
                                "value"
                            ]
                        }
                    }
                }'

                Mock -CommandName Get-Content -ParameterFilter { $Path -eq $testFile1Name } -MockWith {
                    $fileContent
                }

                $expectedContent = Format-ExpectedResult -expectedJson $expectedContent

                Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
                    -Scope It
            }

            It 'Should replace array values correctly (JSON Object) - second' {

                $config = [pscustomobject]@{
                    Nested = [pscustomobject]@{
                        Source      = "calculated"
                        Description = "A Test Value"
                        Value       = @(
                            "1",
                            "2",
                            "3"
                        )
                        Targets     = @(
                            [pscustomobject]@{
                                Name        = "parValue.value"
                                Destination = "Parameters"
                            })
                    }
                }

                $fileContent = '{
                    "parameters": {
                        "parValue": {
                            "value": ["replace_me"]
                        }
                    }
                }'

                $expectedContent = '{
                    "parameters": {
                        "parValue": {
                            "value":  ["1", "2", "3"]
                        }
                    }
                }'

                Mock -CommandName Get-Content -ParameterFilter { $Path -eq $testFile1Name } -MockWith {
                    $fileContent
                }

                $expectedContent = Format-ExpectedResult -expectedJson $expectedContent

                Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
                    -Scope It
            }

            It 'Should not write to files that havent been changed.' {
                $config = Initialize-TestConfiguration -configTarget "DoesnotExist.value" -withValue "value"

                $fileContent = '{
                    "parameters": {
                        "parValue": {
                            "value": "replace_me"
                        }
                    }
                }'

                Mock -CommandName Get-Content -ParameterFilter { $Path -eq $testFile1Name } -MockWith {
                    $fileContent
                }

                Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -Scope It `
                    -Times 0 -Exactly
            }

            It 'Should replace simple values correctly (Bicep Object)' {
                $config = Initialize-TestConfiguration -configTarget "parValue.value" -withValue "value"

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

                Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
                    -Scope It
            }

            It "Should replace 'Parameter' destinations to nested array objects correctly" {
                $config = Initialize-TestConfiguration -configTarget "parNested.value.[0].parChildValue.value" -withValue "nested"

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

                Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
                    -Scope It
            }

            It 'Should replace nested values correctly (Plain JSON Object)' {
                $config = Initialize-TestConfiguration -configTarget "parNested.value.parChildValue" -withValue "nested"

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

                Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination '.' -configuration $config

                Should -Invoke -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $testFile1Name -and $InputObject -eq $expectedContent } `
                    -Scope It
            }

            It 'Should replace nested values correctly (Bicep Object)' {
                $config = Initialize-TestConfiguration -configTarget "parNested.value.parChildValue.value" -withValue "nested"

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

                Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination '.' -configuration $config

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
                        Source      = "calculated"
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

                Set-ComputedConfiguration -configuration $defaultConfig
                Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination '.' -configuration $defaultConfig

                Should -Invoke -CommandName Out-File -Scope It -Times 2

                # Assert that the file was written back with the new values
                $contentAfterParsing = ConvertFrom-Json -InputObject $firstFileContent -AsHashtable
                $contentAfterParsing.parameters.parTopLevelManagementGroupPrefix.value = 'test'
                $contentAfterParsing.parameters.parCompanyPrefix.value = 'test'
                $contentAfterParsing.parameters.parLogging.value = "logs/dev/eastus"

                $contentStringAfterParsing = ConvertTo-Json -InputObject $contentAfterParsing
                Write-InformationColored $contentStringAfterParsing -ForegroundColor Yellow -InformationAction Continue
                Should -Invoke -CommandName Out-File -ParameterFilter { $FilePath -eq "test1.parameters.json" -and $InputObject -eq $contentStringAfterParsing } -Scope It

                $contentAfterParsing = ConvertFrom-Json -InputObject $secondFileContent -AsHashtable
                $contentAfterParsing.parameters.parLocation.value = 'eastus'

                $contentStringAfterParsing = ConvertTo-Json -InputObject $contentAfterParsing
                Write-InformationColored $contentStringAfterParsing -ForegroundColor Yellow -InformationAction Continue
                Should -Invoke -CommandName Out-File -ParameterFilter { $FilePath -eq "test2.parameters.json" -and $InputObject -eq $contentStringAfterParsing } -Scope It
            }

            It 'Multiple files with file specific configuration should be changed correctly' {
                $defaultConfig = [pscustomobject]@{
                    Value1 = [pscustomobject]@{
                        Description  = "The prefix that will be added to all resources created by this deployment."
                        Targets      = @(
                            [pscustomobject]@{
                                File        = "test1.parameters.json"
                                Name        = "parCompanyPrefix.value"
                                Destination = "Parameters"
                            })
                        Value        = "value1"
                        DefaultValue = "alz"
                    }
                    Value2 = [pscustomobject]@{
                        Description  = "The prefix that will be added to all resources created by this deployment."
                        Targets      = @(
                            [pscustomobject]@{
                                File        = "test2.parameters.json"
                                Name        = "parCompanyPrefix.value"
                                Destination = "Parameters"
                            })
                        Value        = "value2"
                        DefaultValue = "alz"
                    }
                }

                $firstFileContent = '{
                    "parameters": {
                        "parCompanyPrefix": {
                            "value": ""
                        },
                    }
                }'
                $secondFileContent = '{
                    "parameters": {
                        "parCompanyPrefix": {
                            "value": ""
                        },
                    }
                }'

                Mock -CommandName Get-ChildItem -ParameterFilter { $Path -match 'config$' } -MockWith {
                    @(
                        [PSCustomObject]@{
                            Name     = 'test1.parameters.json'
                            FullName = 'test1.parameters.json'
                        },
                        [PSCustomObject]@{
                            Name     = 'test2.parameters.json'
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

                Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination '.' -configuration $defaultConfig

                Should -Invoke -CommandName Out-File -Scope It -Times 2

                # Assert that the file was written back with the new values
                $contentAfterParsing = ConvertFrom-Json -InputObject $firstFileContent -AsHashtable
                $contentAfterParsing.parameters.parCompanyPrefix.value = 'value1'

                $contentStringAfterParsing = ConvertTo-Json -InputObject $contentAfterParsing
                Write-InformationColored $contentStringAfterParsing -ForegroundColor Yellow -InformationAction Continue
                Should -Invoke -CommandName Out-File -ParameterFilter { $FilePath -eq "test1.parameters.json" -and $InputObject -eq $contentStringAfterParsing } -Scope It

                $contentAfterParsing = ConvertFrom-Json -InputObject $secondFileContent -AsHashtable
                $contentAfterParsing.parameters.parCompanyPrefix.value = 'value2'

                $contentStringAfterParsing = ConvertTo-Json -InputObject $contentAfterParsing
                Write-InformationColored $contentStringAfterParsing -ForegroundColor Yellow -InformationAction Continue
                Should -Invoke -CommandName Out-File -ParameterFilter { $FilePath -eq "test2.parameters.json" -and $InputObject -eq $contentStringAfterParsing } -Scope It

            }
        }
    }
}
