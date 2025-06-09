#-------------------------------------------------------------------------
Set-Location -Path $PSScriptRoot
#-------------------------------------------------------------------------
$ModuleName = 'ALZ'
$PathToManifest = [System.IO.Path]::Combine('..', '..', $ModuleName, "$ModuleName.psd1")
#-------------------------------------------------------------------------
if (Get-Module -Name $ModuleName -ErrorAction 'SilentlyContinue') {
    #if the module is already in memory, remove it
    Remove-Module -Name $ModuleName -Force
}
Import-Module $PathToManifest -Force
#-------------------------------------------------------------------------

InModuleScope 'ALZ' {
    Describe 'GitHub Actions Repository Access Level Integration Tests' -Tag Integration {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Parameter should be handled in configuration flow' {
            It 'Should handle github_actions_repository_access_level in Convert-ParametersToInputConfig' {
                # Test parameter conversion from command line or environment
                $parameters = @{
                    github_actions_repository_access_level = @{
                        type = "String"
                        value = "organization"
                        aliases = @()
                    }
                }

                $inputConfig = [PSCustomObject]@{}
                $result = Convert-ParametersToInputConfig -inputConfig $inputConfig -parameters $parameters

                $result.github_actions_repository_access_level.Value | Should -Be "organization"
                $result.github_actions_repository_access_level.Source | Should -Be "parameter"
            }
        }
    }
}