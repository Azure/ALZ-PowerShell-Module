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
    Describe 'GitHub Actions Repository Access Level Parameter Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Set-Config should handle github_actions_repository_access_level parameter' {
            It 'Should accept valid github_actions_repository_access_level values' {
                # Test configuration with github_actions_repository_access_level parameter
                $inputConfig = [PSCustomObject]@{
                    github_actions_repository_access_level = @{
                        Value = "organization"
                        Source = "user"
                    }
                }
                
                $configurationParameters = [PSCustomObject]@{
                    github_actions_repository_access_level = [PSCustomObject]@{
                        Value = ""
                        Source = "input"
                        Description = "GitHub Actions repository access level for private repositories"
                        DefaultValue = "organization"
                    }
                }

                $result = Set-Config -configurationParameters $configurationParameters -inputConfig $inputConfig

                $result.github_actions_repository_access_level.Value | Should -Be "organization"
            }

            It 'Should use default value when parameter not provided' {
                # Test with empty input config
                $inputConfig = [PSCustomObject]@{}
                
                $configurationParameters = [PSCustomObject]@{
                    github_actions_repository_access_level = [PSCustomObject]@{
                        Value = ""
                        Source = "input"
                        Description = "GitHub Actions repository access level for private repositories"
                        DefaultValue = "organization"
                    }
                }

                $result = Set-Config -configurationParameters $configurationParameters -inputConfig $inputConfig

                $result.github_actions_repository_access_level.Value | Should -Be "organization"
            }

            It 'Should accept environment variable TF_VAR_github_actions_repository_access_level' {
                # Set environment variable
                $env:TF_VAR_github_actions_repository_access_level = "enterprise"
                
                try {
                    $inputConfig = [PSCustomObject]@{}
                    
                    $configurationParameters = [PSCustomObject]@{
                        github_actions_repository_access_level = [PSCustomObject]@{
                            Value = ""
                            Source = "input"
                            Description = "GitHub Actions repository access level for private repositories"
                            DefaultValue = "organization"
                        }
                    }

                    $result = Set-Config -configurationParameters $configurationParameters -inputConfig $inputConfig

                    $result.github_actions_repository_access_level.Value | Should -Be "sourced-from-env"
                }
                finally {
                    # Clean up environment variable
                    Remove-Item -Path "env:TF_VAR_github_actions_repository_access_level" -ErrorAction SilentlyContinue
                }
            }
        }
    }
}