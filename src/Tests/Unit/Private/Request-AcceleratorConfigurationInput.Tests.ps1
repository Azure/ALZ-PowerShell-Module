#-------------------------------------------------------------------------
Set-Location -Path $PSScriptRoot
#-------------------------------------------------------------------------
$ModuleName = 'ALZ'
$PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
#-------------------------------------------------------------------------
if (Get-Module -Name $ModuleName -ErrorAction 'SilentlyContinue') {
    Remove-Module -Name $ModuleName -Force
}
Import-Module $PathToManifest -Force
#-------------------------------------------------------------------------

InModuleScope 'ALZ' {
    Describe 'Request-AcceleratorConfigurationInput Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }

        Context 'When skipping interactive configuration but continuing' {
            It 'invokes SensitiveOnly check for missing sensitive inputs' {
                $script:answers = @(
                    'C:\\temp\\acc', # target folder
                    'n',               # overwrite existing folder?
                    'n',               # configure inputs now?
                    'yes'              # continue?
                )
                $script:idx = 0
                $prompts = [System.Collections.Generic.List[string]]::new()
                Mock -CommandName Read-Host -MockWith {
                    param($Prompt)
                    $prompts.Add($Prompt) | Out-Null
                    if ($script:idx -lt $script:answers.Count) {
                        $script:answers[$script:idx++]
                    } else {
                        'yes'
                    }
                }

                Mock -CommandName Get-NormalizedPath -MockWith { param($Path) $Path }
                Mock -CommandName Get-AcceleratorFolderConfiguration -MockWith {
                    [pscustomobject]@{
                        FolderExists      = $true
                        IsValid           = $true
                        ConfigFolderPath  = 'C:\\temp\\acc\\config'
                        InputsYamlPath    = 'C:\\temp\\acc\\config\\inputs.yaml'
                        IacType           = 'terraform'
                        VersionControl    = 'github'
                        OutputFolderPath  = 'C:\\temp\\acc\\output'
                    }
                }
                Mock -CommandName Resolve-Path -MockWith { param($Path) [pscustomobject]@{ Path = $Path } }
                Mock -CommandName Get-Command -MockWith { $null }
                Mock -CommandName Get-AzureContext -MockWith { @{ ManagementGroups = @(); Subscriptions = @(); Regions = @() } }
                Mock -CommandName Request-ALZConfigurationValue -MockWith { }
                Mock -CommandName Get-AcceleratorConfigPath -MockWith {
                    [pscustomobject]@{
                        InputConfigFilePaths    = @('inputs.yaml')
                        StarterAdditionalFiles  = @()
                    }
                }
                Mock -CommandName ConvertTo-AcceleratorResult -MockWith {
                    param($Continue, $InputConfigFilePaths, $StarterAdditionalFiles, $OutputFolderPath)
                    @{ Continue = $Continue; InputConfigFilePaths = $InputConfigFilePaths; StarterAdditionalFiles = $StarterAdditionalFiles; OutputFolderPath = $OutputFolderPath }
                }

                $result = Request-AcceleratorConfigurationInput

                # Debug: $prompts and $script:answers can be inspected if needed

                $result.Continue | Should -BeTrue

                Should -Invoke -CommandName Request-ALZConfigurationValue -ParameterFilter { $SensitiveOnly } -Times 1 -Scope It
                # Get-AzureContext is now called lazily inside Request-ALZConfigurationValue, not by Request-AcceleratorConfigurationInput
                Should -Invoke -CommandName Get-AzureContext -Times 0 -Scope It
            }
        }

        Context 'When configuring interactively' {
            It 'does not invoke SensitiveOnly check' {
                $script:answers = @(
                    'C:\\temp\\acc', # target folder
                    'n',               # overwrite existing folder?
                    '',                # configure inputs now? (default yes)
                    'yes'              # continue?
                )
                $script:idx = 0
                Mock -CommandName Read-Host -MockWith {
                    param($Prompt)
                    if ($script:idx -lt $script:answers.Count) {
                        $script:answers[$script:idx++]
                    } else {
                        'yes'
                    }
                }

                Mock -CommandName Get-NormalizedPath -MockWith { param($Path) $Path }
                Mock -CommandName Get-AcceleratorFolderConfiguration -MockWith {
                    [pscustomobject]@{
                        FolderExists      = $true
                        IsValid           = $true
                        ConfigFolderPath  = 'C:\\temp\\acc\\config'
                        InputsYamlPath    = 'C:\\temp\\acc\\config\\inputs.yaml'
                        IacType           = 'terraform'
                        VersionControl    = 'github'
                        OutputFolderPath  = 'C:\\temp\\acc\\output'
                    }
                }
                Mock -CommandName Resolve-Path -MockWith { param($Path) [pscustomobject]@{ Path = $Path } }
                Mock -CommandName Get-Command -MockWith { $null }
                Mock -CommandName Get-AzureContext -MockWith { @{ ManagementGroups = @(); Subscriptions = @(); Regions = @() } }
                Mock -CommandName Request-ALZConfigurationValue -MockWith { }
                Mock -CommandName Get-AcceleratorConfigPath -MockWith {
                    [pscustomobject]@{
                        InputConfigFilePaths    = @('inputs.yaml')
                        StarterAdditionalFiles  = @()
                    }
                }
                Mock -CommandName ConvertTo-AcceleratorResult -MockWith {
                    param($Continue, $InputConfigFilePaths, $StarterAdditionalFiles, $OutputFolderPath)
                    @{ Continue = $Continue; InputConfigFilePaths = $InputConfigFilePaths; StarterAdditionalFiles = $StarterAdditionalFiles; OutputFolderPath = $OutputFolderPath }
                }

                $result = Request-AcceleratorConfigurationInput

                $result.Continue | Should -BeTrue

                Should -Invoke -CommandName Request-ALZConfigurationValue -ParameterFilter { $SensitiveOnly } -Times 0 -Scope It
            }
        }
    }
}
