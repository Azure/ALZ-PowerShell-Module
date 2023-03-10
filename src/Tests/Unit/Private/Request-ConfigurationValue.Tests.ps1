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
    Describe 'Request-ConfigurationValue Public Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'User inputs requested value' {
            BeforeEach {
                Mock -CommandName Write-InformationColored -MockWith {
                    $null
                }

                Mock -CommandName Read-Host -MockWith {
                    "user input value"
                }
            }
            It 'Prompt the user for configuration with a default value.' {
                $configValue = @{
                    description  = "The prefix that will be added to all resources created by this deployment."
                    names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
                    value        = "alz"
                    defaultValue = "alz"
                }

                Request-ConfigurationValue -configName "prefix" -configValue $configValue

                Assert-MockCalled -CommandName Write-InformationColored -Times 3

                $configValue.value | Should -BeExactly "user input value"
            }
        }
    }
}
