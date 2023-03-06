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
    Describe 'Write-InformationColored Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Initialize config get the correct base values' {
            BeforeEach {
                Mock -CommandName Write-Information -MockWith {
                    $null
                }
            }
            It 'should make sure that the information it is printed correctly' {
                Write-InformationColored -Message 'test' -ForegroundColor 'Green'
                $info = [System.Management.Automation.HostInformationMessage]@{
                    Message         = 'test'
                    ForegroundColor = 'Green'
                    BackgroundColor = $Host.UI.RawUI.BackgroundColor
                    NoNewline       = $false
                }

                # Check that Write-Information was called with the correct parameters
                Assert-MockCalled -CommandName Write-Information -Exactly 1 -Scope It -ParameterFilter {
                    $MessageData.Message -eq $info.Message -and `
                        $MessageData.ForegroundColor -eq $info.ForegroundColor -and `
                        $MessageData.BackgroundColor -eq $info.BackgroundColor -and `
                        $MessageData.NoNewline -eq $info.NoNewline
                }
            }
        }
    }
}
