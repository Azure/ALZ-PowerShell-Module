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
    Describe 'New-Bootstrap architecture file handling' -Tag Unit {
        BeforeAll {
            Import-Module powershell-yaml -ErrorAction Stop

            function Add-TestFile {
                param([string] $Path, [string] $Content)
                New-Item -Path (Split-Path $Path -Parent) -ItemType Directory -Force | Out-Null
                Set-Content -Path $Path -Value $Content
            }

            function Get-TestInputConfig {
                [PSCustomObject]@{
                    starter_module_name = @{ Value = 'platform_landing_zone'; Source = 'input'; Sensitive = $false }
                }
            }

            function Invoke-TestBootstrap {
                param([PSCustomObject] $InputConfig)
                New-Bootstrap `
                    -iac 'terraform' `
                    -bootstrapDetails ([PSCustomObject]@{ Value = [PSCustomObject]@{ location = 'alz/local' } }) `
                    -inputConfig $InputConfig `
                    -bootstrapTargetPath $bootstrapTargetPath `
                    -bootstrapRelease 'v1.0.0' `
                    -hasStarter `
                    -starterTargetPath $starterTargetPath `
                    -starterRelease 'v2.0.0' `
                    -starterConfig ([PSCustomObject]@{ starter_modules = [PSCustomObject]@{ Value = [PSCustomObject]@{ platform_landing_zone = [PSCustomObject]@{ location = 'platform_landing_zone' } } } }) `
                    -hclParserToolPath 'hcl2json' `
                    -starterAdditionalFiles @($userLibPath) `
                    -autoApprove
            }
        }

        BeforeEach {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $bootstrapTargetPath = Join-Path $root 'boot-module'
            $starterTargetPath = Join-Path $root 'starter-module'
            $userLibPath = Join-Path $root 'config/lib'
            $bootstrapTfvarsPath = Join-Path $bootstrapTargetPath 'v1.0.0/alz/local/terraform.tfvars.json'
            $starterModulePath = Join-Path $starterTargetPath 'v2.0.0/platform_landing_zone'
            $starterDefaultFile = Join-Path $starterModulePath 'lib/architecture_definitions/alz_custom.alz_architecture_definition.yaml'

            Add-TestFile -Path (Join-Path $bootstrapTargetPath 'v1.0.0/alz/local/variables.tf') -Content ''
            Add-TestFile -Path (Join-Path $starterModulePath 'variables.tf') -Content ''
            Add-TestFile -Path $starterDefaultFile -Content "name: alz_custom`nmanagement_groups: []"
            New-Item -Path $userLibPath -ItemType Directory -Force | Out-Null

            Mock -CommandName Convert-HCLVariablesToInputConfig -ParameterFilter { $targetVariableFile -like '*boot-module*' } -MockWith {
                [PSCustomObject]@{
                    terraform_architecture_file_path = [PSCustomObject]@{
                        Value        = ''
                        Source       = 'input'
                        DefaultValue = 'lib/architecture_definitions/alz_custom.alz_architecture_definition.yaml'
                        Description  = ''
                        Sensitive    = $false
                    }
                }
            }
            Mock -CommandName Convert-HCLVariablesToInputConfig -ParameterFilter { $targetVariableFile -like '*starter-module*' } -MockWith { [PSCustomObject]@{} }
            Mock -CommandName Invoke-Terraform -MockWith { }
            Mock -CommandName Write-ToConsoleLog -MockWith { }
        }

        It 'passes a renamed architecture file to the bootstrap and removes the duplicate default' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: alz_custom'

            Invoke-TestBootstrap -InputConfig (Get-TestInputConfig)

            (Get-Content $bootstrapTfvarsPath -Raw | ConvertFrom-Json).terraform_architecture_file_path | Should -Be 'lib/architecture_definitions/contoso.alz_architecture_definition.yaml'
            Test-Path (Join-Path $starterModulePath 'lib/architecture_definitions/contoso.alz_architecture_definition.yaml') | Should -BeTrue
            Test-Path $starterDefaultFile | Should -BeFalse
        }

        It 'keeps the default architecture file path when the user lib has no architecture file' {
            Add-TestFile -Path (Join-Path $userLibPath 'archetype_definitions/root_custom.alz_archetype_override.yaml') -Content 'name: root_custom'

            Invoke-TestBootstrap -InputConfig (Get-TestInputConfig)

            (Get-Content $bootstrapTfvarsPath -Raw | ConvertFrom-Json).terraform_architecture_file_path | Should -Be 'lib/architecture_definitions/alz_custom.alz_architecture_definition.yaml'
            Test-Path $starterDefaultFile | Should -BeTrue
        }

        It 'keeps an explicit architecture file path input and the default file' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: alz_custom'
            $inputConfig = Get-TestInputConfig
            $inputConfig | Add-Member -NotePropertyName 'terraform_architecture_file_path' -NotePropertyValue @{ Value = 'lib/architecture_definitions/explicit.alz_architecture_definition.yaml'; Source = '.yaml'; Sensitive = $false }

            Invoke-TestBootstrap -InputConfig $inputConfig

            (Get-Content $bootstrapTfvarsPath -Raw | ConvertFrom-Json).terraform_architecture_file_path | Should -Be 'lib/architecture_definitions/explicit.alz_architecture_definition.yaml'
            Test-Path $starterDefaultFile | Should -BeTrue
        }

        It 'uses the architecture name from the platform landing zone inputs' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.json') -Content '{ "name": "contoso" }'
            $inputConfig = Get-TestInputConfig
            $inputConfig | Add-Member -NotePropertyName 'management_group_settings' -NotePropertyValue @{ Value = [PSCustomObject]@{ architecture_name = 'contoso' }; Source = '.tfvars'; Sensitive = $false }

            Invoke-TestBootstrap -InputConfig $inputConfig

            (Get-Content $bootstrapTfvarsPath -Raw | ConvertFrom-Json).terraform_architecture_file_path | Should -Be 'lib/architecture_definitions/contoso.alz_architecture_definition.json'
            Test-Path $starterDefaultFile | Should -BeTrue
        }

        It 'gives the same result when run again on the same output folder' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: alz_custom'

            Invoke-TestBootstrap -InputConfig (Get-TestInputConfig)
            Invoke-TestBootstrap -InputConfig (Get-TestInputConfig)

            (Get-Content $bootstrapTfvarsPath -Raw | ConvertFrom-Json).terraform_architecture_file_path | Should -Be 'lib/architecture_definitions/contoso.alz_architecture_definition.yaml'
            Test-Path $starterDefaultFile | Should -BeFalse
        }
    }
}
