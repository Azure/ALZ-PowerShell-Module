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
    Describe 'Get-ALZGithubRelease Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Initialize config get the correct base values' {
            BeforeEach {
                Mock -CommandName Invoke-RestMethod -ParameterFilter { $Uri -eq "https://api.github.com/repos/test/repo/releases" } -MockWith {
                    @(
                        [PSCustomObject]@{
                            name         = "v1.0.0"
                            tag_name     = "v1.0.0"
                            published_at = "2020-01-01T00:00:00Z"
                            prerelease   = $false
                            draft        = $false
                            html_url     = ""
                        },
                        [PSCustomObject]@{
                            name         = "v1.0.1"
                            tag_name     = "v1.0.1"
                            published_at = "2020-01-02T00:00:00Z"
                            prerelease   = $false
                            draft        = $false
                            html_url     = ""
                        }
                    )
                }

                Mock -CommandName Invoke-WebRequest -ParameterFilter { $Uri -eq "https://github.com/test/repo/archive/refs/tags/v1.0.1.zip" } -MockWith {
                    [PSCustomObject]@{
                        ContentLength64 = 100
                    }
                }

                Mock -CommandName Invoke-WebRequest -ParameterFilter { $Uri -eq "https://github.com/test/repo/archive/refs/tags/v1.0.0.zip" } -MockWith {
                    [PSCustomObject]@{
                        ContentLength64 = 102
                    }
                }

                Mock -CommandName Expand-Archive -MockWith {
                    $null
                }

                Mock -CommandName Remove-Item -MockWith {
                    $null
                }

                Mock -CommandName Get-ChildItem -ParameterFilter { $Path -eq "output/v1.0.1" } -MockWith {
                    $null
                }

                Mock -CommandName Get-ChildItem -ParameterFilter { $Path -eq "output/v1.0.0" } -MockWith {
                    $null
                }

                Mock -CommandName Get-ChildItem -ParameterFilter { $Path -eq "output/v1.0.1/tmp/extracted" } -MockWith {
                    @(
                        [PSCustomObject]@{
                            FullName = "Internal-Folder"
                        }
                    )
                }

                Mock -CommandName Get-ChildItem -ParameterFilter { $Path -eq "output/v1.0.0/tmp/extracted" } -MockWith {
                    @(
                        [PSCustomObject]@{
                            FullName = "Internal-Folder"
                        }
                    )
                }

                Mock -CommandName New-Item -MockWith {
                    $null
                }

                Mock -CommandName Move-Item -MockWith {
                    $null
                }

                Mock -CommandName Write-Warning -MockWith {
                    $null
                }

            }

            It 'Should get the correct releases' {
                Get-ALZGithubRelease -githubRepoUrl "http://github.com/test/repo" -directoryAndFilesToKeep @('repo-1.0.0') -directoryForReleases "output"
                Should -Invoke Expand-Archive
                Should -Not -Invoke Write-Warning
            }

            It 'Should warn when you ask for a release that does not exist' {
                Get-ALZGithubRelease -githubRepoUrl "http://github.com/test/repo" -releases @('v2.0.0') -directoryAndFilesToKeep @('repo-1.0.0') -directoryForReleases "output"
                Should -Invoke Write-Warning
            }

            It 'Should download all the releases with all' {
                Get-ALZGithubRelease -githubRepoUrl "http://github.com/test/repo" -releases @('all') -directoryAndFilesToKeep @('repo-1.0.0') -directoryForReleases "output"
                Should -Invoke Expand-Archive -Times 2
                Should -Not -Invoke Write-Warning
            }
        }
    }
}
