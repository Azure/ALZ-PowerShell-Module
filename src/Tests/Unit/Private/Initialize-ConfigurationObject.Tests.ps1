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
    Describe 'Initialize-ConfigurationObject Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Initialize config get the correct base values' {
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
                $content[0].description | Should -BeExactly "The prefix that will be added to all resources created by this deployment."
                $content[0].names | Should -BeExactly @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                $content[0].value | Should -BeExactly "alz"
                $content[0].defaultValue | Should -BeExactly "alz"
                $content[1].description | Should -BeExactly "The suffix that will be added to all resources created by this deployment."
                $content[1].names | Should -BeExactly @("parTopLevelManagementGroupSuffix")
                $content[1].value | Should -BeExactly ""
                $content[1].defaultValue | Should -BeExactly ""
                $content[2].description | Should -BeExactly "Deployment location."
                $content[2].names | Should -BeExactly @("parLocation")
                $content[2].allowedValues | Should -BeExactly @('eastus', 'ukwest')
                $content[2].value | Should -BeExactly ""
            }
        }
    }
}
