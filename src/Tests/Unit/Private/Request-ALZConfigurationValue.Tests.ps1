#-------------------------------------------------------------------------
Set-Location -Path $PSScriptRoot
#-------------------------------------------------------------------------

$ModuleName = 'ALZ'
$PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")

if (Get-Module -Name $ModuleName -ErrorAction 'SilentlyContinue') {
    Remove-Module -Name $ModuleName -Force
}

Import-Module $PathToManifest -Force
#-------------------------------------------------------------------------

InModuleScope 'ALZ' {
    Describe 'Request-ALZConfigurationValue Function Tests' -Tag Unit {

        Context 'When ScenarioNumber is 5 and optional platform subscriptions are left empty' {

            It 'does not use matching Azure subscriptions as defaults for optional platform subscriptions' {

                $testConfigPath = Join-Path $TestDrive 'config'
                New-Item -Path $testConfigPath -ItemType Directory -Force | Out-Null

                $inputsYamlPath = Join-Path $testConfigPath 'inputs.yaml'

                @'
---
subscription_ids:
  management: "management-id"
  connectivity: ""
  identity: ""
  security: ""
'@ | Set-Content -Path $inputsYamlPath

                Mock Get-AzureContext {
                    param(
                        $OutputDirectory,
                        $ClearCache
                    )

                    return @{
                        Subscriptions = @(
                            [PSCustomObject]@{
                                name  = 'Management'
                                value = 'management-id'
                            },
                            [PSCustomObject]@{
                                name  = 'Connectivity'
                                value = 'connectivity-id'
                            },
                            [PSCustomObject]@{
                                name  = 'Identity'
                                value = 'identity-id'
                            },
                            [PSCustomObject]@{
                                name  = 'Security'
                                value = 'security-id'
                            }
                        )
                        ManagementGroups      = @()
                        Regions               = @()
                        CurrentSubscriptionId = 'management-id'
                        CurrentTenantId       = 'tenant-id'
                    }
                }

                Mock Write-ToConsoleLog {}

                Mock Read-MenuSelection {
                    param(
                        $Title,
                        $DefaultValue,
                        $DefaultToManualEntry
                    )

                    switch ($Title) {
                        'management' {
                            return 'management-id'
                        }

                        'connectivity' {
                            $DefaultValue | Should -Be ''
                            $DefaultToManualEntry | Should -BeTrue
                            return ''
                        }

                        'identity' {
                            $DefaultValue | Should -Be ''
                            $DefaultToManualEntry | Should -BeTrue
                            return ''
                        }

                        'security' {
                            $DefaultValue | Should -Be ''
                            $DefaultToManualEntry | Should -BeTrue
                            return ''
                        }

                        default {
                            return ''
                        }
                    }
                }

                Request-ALZConfigurationValue `
                    -ConfigFolderPath $testConfigPath `
                    -IacType 'terraform' `
                    -VersionControl 'local' `
                    -AzureContextOutputDirectory $TestDrive `
                    -ScenarioNumber 5 `
                    -Confirm:$false

                $updatedContent = Get-Content -Path $inputsYamlPath -Raw

                $updatedContent | Should -Match 'management: "management-id"'
                $updatedContent | Should -Not -Match 'connectivity-id'
                $updatedContent | Should -Not -Match 'identity-id'
                $updatedContent | Should -Not -Match 'security-id'
            }
        }

        Context 'When ScenarioNumber is 5 and an optional platform subscription already exists' {

            It 'preserves an existing optional subscription value' {

                $testConfigPath = Join-Path $TestDrive 'config'
                New-Item -Path $testConfigPath -ItemType Directory -Force | Out-Null

                $inputsYamlPath = Join-Path $testConfigPath 'inputs.yaml'

                @'
---
subscription_ids:
  management: "management-id"
  connectivity: "existing-connectivity-id"
  identity: "existing-identity-id"
  security: "existing-security-id"
'@ | Set-Content -Path $inputsYamlPath

                Mock Get-AzureContext {
                    param(
                        $OutputDirectory,
                        $ClearCache
                    )

                    return @{
                        Subscriptions = @(
                            [PSCustomObject]@{
                                name  = 'Management'
                                value = 'management-id'
                            },
                            [PSCustomObject]@{
                                name  = 'Connectivity'
                                value = 'connectivity-id'
                            },
                            [PSCustomObject]@{
                                name  = 'Identity'
                                value = 'identity-id'
                            },
                            [PSCustomObject]@{
                                name  = 'Security'
                                value = 'security-id'
                            }
                        )
                        ManagementGroups      = @()
                        Regions               = @()
                        CurrentSubscriptionId = 'management-id'
                        CurrentTenantId       = 'tenant-id'
                    }
                }

                Mock Write-ToConsoleLog {}

                Mock Read-MenuSelection {
                    param($Title)

                    switch ($Title) {
                        'management' {
                            return 'management-id'
                        }

                        'connectivity' {
                            return 'existing-connectivity-id'
                        }

                        'identity' {
                            return 'existing-identity-id'
                        }

                        'security' {
                            return 'existing-security-id'
                        }

                        default {
                            return ''
                        }
                    }
                }

                Request-ALZConfigurationValue `
                    -ConfigFolderPath $testConfigPath `
                    -IacType 'terraform' `
                    -VersionControl 'local' `
                    -AzureContextOutputDirectory $TestDrive `
                    -ScenarioNumber 5 `
                    -Confirm:$false

                $updatedContent = Get-Content -Path $inputsYamlPath -Raw

                $updatedContent | Should -Match 'management: "management-id"'
                $updatedContent | Should -Match 'connectivity: "existing-connectivity-id"'
                $updatedContent | Should -Match 'identity: "existing-identity-id"'
                $updatedContent | Should -Match 'security: "existing-security-id"'
            }
        }

        Context 'When ScenarioNumber is 5 and an existing optional subscription is cleared' {

            It 'clears the optional subscription without using an Azure subscription as a replacement' {

                $testConfigPath = Join-Path $TestDrive 'config'
                New-Item -Path $testConfigPath -ItemType Directory -Force | Out-Null

                $inputsYamlPath = Join-Path $testConfigPath 'inputs.yaml'

                @'
---
subscription_ids:
  management: "management-id"
  connectivity: "existing-connectivity-id"
  identity: "existing-identity-id"
  security: "existing-security-id"
'@ | Set-Content -Path $inputsYamlPath

                Mock Get-AzureContext {
                    param(
                        $OutputDirectory,
                        $ClearCache
                    )

                    return @{
                        Subscriptions = @(
                            [PSCustomObject]@{
                                name  = 'Management'
                                value = 'management-id'
                            },
                            [PSCustomObject]@{
                                name  = 'Connectivity'
                                value = 'connectivity-id'
                            },
                            [PSCustomObject]@{
                                name  = 'Identity'
                                value = 'identity-id'
                            },
                            [PSCustomObject]@{
                                name  = 'Security'
                                value = 'security-id'
                            }
                        )
                        ManagementGroups      = @()
                        Regions               = @()
                        CurrentSubscriptionId = 'management-id'
                        CurrentTenantId       = 'tenant-id'
                    }
                }

                Mock Write-ToConsoleLog {}

                Mock Read-MenuSelection {
                    param($Title)

                    switch ($Title) {
                        'management' {
                            return 'management-id'
                        }

                        'connectivity' {
                            return 'existing-connectivity-id'
                        }

                        'identity' {
                            return ''
                        }

                        'security' {
                            return 'existing-security-id'
                        }

                        default {
                            return ''
                        }
                    }
                }

                Request-ALZConfigurationValue `
                    -ConfigFolderPath $testConfigPath `
                    -IacType 'terraform' `
                    -VersionControl 'local' `
                    -AzureContextOutputDirectory $TestDrive `
                    -ScenarioNumber 5 `
                    -Confirm:$false

                $updatedContent = Get-Content -Path $inputsYamlPath -Raw

                $updatedContent | Should -Match 'management: "management-id"'
                $updatedContent | Should -Match 'connectivity: "existing-connectivity-id"'
                $updatedContent | Should -Match 'security: "existing-security-id"'
                $updatedContent | Should -Not -Match 'identity-id'
            }
        }
    }
}
