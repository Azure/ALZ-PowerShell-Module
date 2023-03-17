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
        $defaultConfig = [pscustomobject]@{
            Prefix      = [pscustomobject]@{
                Description  = "The prefix that will be added to all resources created by this deployment."
                Targets      = @(
                    [pscustomobject]@{
                        Name        = "parTopLevelManagementGroupPrefix"
                        Destination = "Parameters"
                    },
                    [pscustomobject]@{
                        Name        = "parCompanyPrefix"
                        Destination = "Parameters"
                    })
                Value        = "test"
                DefaultValue = "alz"
            }
            Suffix      = [pscustomobject]@{
                Description  = "The suffix that will be added to all resources created by this deployment."
                Targets      = @(
                    [pscustomobject]@{
                        Name        = "parTopLevelManagementGroupSuffix"
                        Destination = "Parameters"
                    })
                Value        = "bla"
                DefaultValue = ""
            }
            Location    = [pscustomobject]@{
                Description   = "Deployment location."
                Targets       = @(
                    [pscustomobject]@{
                        Name        = "parLocation"
                        Destination = "Parameters"
                    })
                AllowedValues = @('ukwest', '')
                Value         = "eastus"
            }
            Environment = [pscustomobject]@{
                Description  = "The type of environment that will be created . Example: dev, test, qa, staging, prod"
                Targets      = @(
                    [pscustomobject]@{
                        Name        = "parEnvironment"
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
                        Name        = "parLogging"
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
    }
    Describe 'Edit-ALZConfigurationFilesInPlace Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Edit-ALZConfigurationFilesInPlace should replace the parameters correctly' {
            BeforeEach {
                Mock -CommandName Get-ChildItem -ParameterFilter { $Path -match 'orchestration$' } -MockWith {
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

                Mock -CommandName Out-File -MockWith {
                    Write-InformationColored "Out-File was called with $FilePath and $InputObject" -ForegroundColor Yellow -InformationAction Continue
                }
            }
            It 'Files should be changed correctly' {
                Edit-ALZConfigurationFilesInPlace  -alzEnvironmentDestination '.' -configuration $defaultConfig

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
                $contentAfterParsing.parameters.parTopLevelManagementGroupSuffix.value = 'bla'
                $contentAfterParsing.parameters.parLocation.value = 'eastus'
                $contentStringAfterParsing = ConvertTo-Json -InputObject $contentAfterParsing
                Write-InformationColored $contentStringAfterParsing -ForegroundColor Yellow -InformationAction Continue
                Should -Invoke -CommandName Out-File -ParameterFilter { $FilePath -eq "test2.parameters.json" -and $InputObject -eq $contentStringAfterParsing } -Scope It
            }
        }
    }
}
