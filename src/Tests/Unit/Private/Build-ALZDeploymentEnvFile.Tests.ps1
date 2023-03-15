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
    Describe 'Build-AZLDeploymentEnvFile Private Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Build-AZLDeploymentEnvFile should create a .env file correctly' {
            It 'Creates a config file based on configuration.' {

                Mock -CommandName New-Item
                Mock -CommandName Add-Content

                $configuration = [pscustomobject]@{
                    Setting1 = [pscustomobject]@{
                        ForEnvironment = $true
                        Value          = "Test1"
                    }
                    Setting2 = [pscustomobject]@{
                        ForEnvironment = $true
                        Value          = "Test2"
                    }
                }

                Build-ALZDeploymentEnvFile -configuration $configuration -destination "test"

                Should -Invoke New-Item -ParameterFilter { $Path -match ".env$" } -Scope It -Times 1 -Exactly
                Should -Invoke Add-Content -ParameterFilter { $Value -match "^Setting1=`"Test1`"$" } -Scope It -Times 1 -Exactly
                Should -Invoke Add-Content -ParameterFilter { $Value -match "^Setting2=`"Test2`"$" } -Scope It -Times 1 -Exactly
            }
            It 'Omits configuration not intended for the .env file.' {

                Mock -CommandName New-Item
                Mock -CommandName Add-Content

                $configuration = [pscustomobject]@{
                    Setting1 = [pscustomobject]@{
                        ForEnvironment = $true
                        Value          = "Test1"
                    }
                    Setting2 = [pscustomobject]@{
                        ForEnvironment = $false
                        Value          = "Test2"
                    }
                }

                Build-ALZDeploymentEnvFile -configuration $configuration -destination "test"

                Should -Invoke New-Item -ParameterFilter { $Path -match ".env$" } -Scope It -Times 1 -Exactly
                Should -Invoke Add-Content -Scope It -Times 1 -Exactly
            }
        }
    }
}