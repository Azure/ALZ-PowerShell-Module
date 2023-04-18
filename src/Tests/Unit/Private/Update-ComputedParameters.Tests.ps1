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
    Describe 'Update-ComputedParameters Private Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Update-ComputedParameters should update the configuration correctly' {
            It 'Handles Computed values correctly.' {
                $configuration = [pscustomobject]@{
                    Setting1 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting1"
                                Destination = "Environment"
                            })
                        Value   = "Test"
                    }
                    Setting2 = [pscustomobject]@{
                        Targets = @(
                            [pscustomobject]@{
                                Name        = "Setting2"
                                Destination = "Environment"
                            })
                        Type    = "Computed"
                        Value   = "{%Setting1%}"
                    }
                }

                Update-ComputedParameters -configuration $configuration
            }
        }
    }
}