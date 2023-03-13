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
    Describe 'New-ALZDirectoryEnvironment Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Create the correctr foldes for the environment' {
            BeforeEach {
                Mock -CommandName Get-AzLocation -MockWith {
                    @(
                        [PSCustomObject]@{
                            Location = 'ukwest'
                        },
                        [PSCustomObject]@{
                            Location = 'eastus'
                        }
                    )
                }
            }
            It 'should return the not met for non AZ module' {
                $content = Initialize-ConfigurationObject
                $content.Prefix.Value | Should -Be 'alz'
                $content.Prefix.DefaultValue | Should -Be 'alz'
                $content.Prefix.Description | Should -Be 'The prefix that will be added to all resources created by this deployment.'
                $content.Prefix.Names | Should -Be @('parTopLevelManagementGroupPrefix', 'parCompanyPrefix', 'parTargetManagementGroupId', 'parAssignableScopeManagementGroupId')

                $content.Suffix.Value | Should -Be ''
                $content.Suffix.DefaultValue | Should -Be ''
                $content.Suffix.Description | Should -Be 'The suffix that will be added to all resources created by this deployment.'
                $content.Suffix.Names | Should -Be @('parTopLevelManagementGroupSuffix')

                $content.Location.Value | Should -Be ''
                $content.Location.Description | Should -Be 'Deployment location.'
                $content.Location.Names | Should -Be @('parLocation')
                $content.Location.AllowedValues | Should -Be @('eastus', 'ukwest')

                $content.Environment.Value | Should -Be ''
                $content.Environment.Description | Should -Be 'The type of environment that will be created. Example: dev, test, qa, staging, prod'
                $content.Environment.Names | Should -Be @('parEnvironment')
                $content.Environment.DefaultValue | Should -Be 'prod'
            }
        }
    }
}
