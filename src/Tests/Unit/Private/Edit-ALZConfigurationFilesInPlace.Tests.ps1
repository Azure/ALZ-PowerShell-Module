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
        $defaultConfig =   [pscustomobject]@{
            Prefix = [pscustomobject]@{
                description  = "The prefix that will be added to all resources created by this deployment."
                names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                value        = "test"
                defaultValue = "alz"
            }
            Suffix = [pscustomobject]@{
                Description  = "The suffix that will be added to all resources created by this deployment."
                Names        = @("parTopLevelManagementGroupSuffix")
                Value        = "bla"
                DefaultValue = ""
            }
            Location = [pscustomobject]@{
                Description   = "Deployment location."
                Names         = @("parLocation")
                AllowedValues = @('ukwest', '')
                Value         = "eastus"
            }
            Environment = [pscustomobject]@{
                Description   = "The type of environment that will be created . Example: dev, test, qa, staging, prod"
                Names         = @("parEnvironment")
                DefaultValue  = 'prod'
                Value         = "dev"
            }
        }
        $firstFileContent = '{
            "parameters": {
                "parTopLevelManagementGroupPrefix": {
                    "value": ""
                },
                "parCompanyPrefix": {
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
                    $firstFileContent
                }
                Mock -CommandName Get-Content -ParameterFilter { $Path -eq 'test2.parameters.json' } -MockWith {
                    $secondFileContent
                }
                Mock -CommandName Out-File -MockWith {}
            }
            It 'Files shuld be changed correctly' {
                Edit-ALZConfigurationFilesInPlace  -alzBicepRoot '.' -configuration $defaultConfig
                # Assert that the file was wirte back with the new values
                Assert-MockCalled -CommandName Out-File -Exactly 2 -Scope It
                $contentAfterParsing = ConvertFrom-Json -InputObject $firstFileContent
                $contentAfterParsing.parameters.parTopLevelManagementGroupPrefix.value = 'test'
                $contentAfterParsing.parameters.parCompanyPrefix.value = 'test'
                $contentStringAfterParsing = ConvertTo-Json -InputObject $contentAfterParsing
                Assert-MockCalled -CommandName Out-File -ParameterFilter { $FilePath -eq "test1.parameters.json" -and $InputObject -eq $contentStringAfterParsing } -Scope It
                $contentAfterParsing = ConvertFrom-Json -InputObject $secondFileContent
                $contentAfterParsing.parameters.parTopLevelManagementGroupSuffix.value = 'bla'
                $contentAfterParsing.parameters.parLocation.value = 'eastus'
                $contentStringAfterParsing = ConvertTo-Json -InputObject $contentAfterParsing
                Assert-MockCalled -CommandName Out-File -ParameterFilter { $FilePath -eq "test2.parameters.json" -and $InputObject -eq $contentStringAfterParsing } -Scope It

            }
        }
    }
}
