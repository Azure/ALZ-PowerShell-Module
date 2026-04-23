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
    Describe 'Test-NetworkConnectivity Private Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }

        Context 'All endpoints are reachable' {
            BeforeAll {
                Mock -CommandName Invoke-HttpRequestWithRetry -MockWith {
                    [PSCustomObject]@{ StatusCode = 200 }
                }
                Mock -CommandName Invoke-GitHubApiRequest -MockWith {
                    @{ StatusCode = 200; Result = $null }
                }
            }

            It 'returns HasFailure = $false when all endpoints succeed' {
                $result = Test-NetworkConnectivity
                $result.HasFailure | Should -BeFalse
            }

            It 'returns a Success result for every endpoint' {
                $result = Test-NetworkConnectivity
                $result.Results | ForEach-Object {
                    $_.result | Should -Be "Success"
                }
            }

            It 'returns one result per endpoint (7 total)' {
                $result = Test-NetworkConnectivity
                $result.Results.Count | Should -Be 7
            }
        }

        Context 'One endpoint is unreachable' {
            BeforeAll {
                Mock -CommandName Invoke-GitHubApiRequest -MockWith {
                    throw "Unable to connect to the remote server"
                }
                Mock -CommandName Invoke-HttpRequestWithRetry -MockWith {
                    [PSCustomObject]@{ StatusCode = 200 }
                }
            }

            It 'returns HasFailure = $true' {
                $result = Test-NetworkConnectivity
                $result.HasFailure | Should -BeTrue
            }

            It 'returns a Failure result for the unreachable endpoint' {
                $result = Test-NetworkConnectivity
                $failureResults = @($result.Results | Where-Object { $_.result -eq "Failure" })
                $failureResults.Count | Should -Be 2
            }

            It 'includes the error message in the Failure result' {
                $result = Test-NetworkConnectivity
                $failureResult = @($result.Results | Where-Object { $_.result -eq "Failure" })[0]
                $failureResult.message | Should -Match "Cannot reach"
                $failureResult.message | Should -Match "api.github.com"
            }

            It 'still returns Success results for the reachable endpoints' {
                $result = Test-NetworkConnectivity
                $successResults = @($result.Results | Where-Object { $_.result -eq "Success" })
                $successResults.Count | Should -Be 5
            }
        }

        Context 'All endpoints are unreachable' {
            BeforeAll {
                Mock -CommandName Invoke-HttpRequestWithRetry -MockWith {
                    throw "Network unreachable"
                }
                Mock -CommandName Invoke-GitHubApiRequest -MockWith {
                    throw "Network unreachable"
                }
            }

            It 'returns HasFailure = $true' {
                $result = Test-NetworkConnectivity
                $result.HasFailure | Should -BeTrue
            }

            It 'returns a Failure result for every endpoint' {
                $result = Test-NetworkConnectivity
                $result.Results | ForEach-Object {
                    $_.result | Should -Be "Failure"
                }
            }

            It 'returns one result per endpoint (7 total)' {
                $result = Test-NetworkConnectivity
                $result.Results.Count | Should -Be 7
            }

            It 'checks all endpoints and does not stop at the first failure' {
                $result = Test-NetworkConnectivity
                Should -Invoke -CommandName Invoke-HttpRequestWithRetry -Times 5 -Scope It
                Should -Invoke -CommandName Invoke-GitHubApiRequest -Times 2 -Scope It
            }
        }
    }
}
