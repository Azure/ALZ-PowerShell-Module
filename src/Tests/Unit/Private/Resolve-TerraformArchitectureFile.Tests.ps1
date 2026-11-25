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
    Describe 'Resolve-TerraformArchitectureFile Function Tests' -Tag Unit {
        BeforeAll {
            Import-Module powershell-yaml -ErrorAction Stop
            $defaultPath = 'lib/architecture_definitions/alz_custom.alz_architecture_definition.yaml'

            function Add-TestFile {
                param([string] $Path, [string] $Content)
                New-Item -Path (Split-Path $Path -Parent) -ItemType Directory -Force | Out-Null
                Set-Content -Path $Path -Value $Content
            }
        }

        BeforeEach {
            Mock -CommandName Write-ToConsoleLog -MockWith { }
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $starterPath = Join-Path $root 'starter'
            $userLibPath = Join-Path $root 'config/lib'
            $starterDefaultFile = Join-Path $starterPath $defaultPath
            Add-TestFile -Path $starterDefaultFile -Content "name: alz_custom`nmanagement_groups:`n  - id: alz`n    parent_id: null"
            Add-TestFile -Path (Join-Path $starterPath 'variables.management.tf') -Content 'variable "management_group_settings" { type = object({ architecture_name = optional(string, "alz_custom") }) }'
            New-Item -Path $userLibPath -ItemType Directory -Force | Out-Null
        }

        It 'makes no change when the user lib has no architecture file' {
            Add-TestFile -Path (Join-Path $userLibPath 'archetype_definitions/root_custom.alz_archetype_override.yaml') -Content 'name: root_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
            $result.DefaultFileToRemove | Should -BeNullOrEmpty
        }

        It 'makes no change when a user file replaces the default path, even with another file for the same architecture' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/alz_custom.alz_architecture_definition.yaml') -Content 'name: foo'
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: alz_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
            $result.DefaultFileToRemove | Should -BeNullOrEmpty
        }

        It 'selects a renamed yaml file with the default architecture name and removes the duplicate default' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: alz_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -Be 'lib/architecture_definitions/contoso.alz_architecture_definition.yaml'
            $result.DefaultFileToRemove | Should -Be $starterDefaultFile
        }

        It 'selects a renamed json file by the architecture name input and keeps the differently named default' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.json') -Content '{ "name": "contoso", "management_groups": [] }'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath -architectureName 'contoso'

            $result.ArchitectureFilePath | Should -Be 'lib/architecture_definitions/contoso.alz_architecture_definition.json'
            $result.DefaultFileToRemove | Should -BeNullOrEmpty
        }

        It 'keeps the subfolder of a nested yml file' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/custom/contoso.alz_architecture_definition.yml') -Content 'name: alz_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -Be 'lib/architecture_definitions/custom/contoso.alz_architecture_definition.yml'
        }

        It 'throws when more than one user file declares the target architecture name' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: alz_custom'
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/fabrikam.alz_architecture_definition.json') -Content '{ "name": "alz_custom" }'

            { Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath } |
                Should -Throw "*lib/architecture_definitions/contoso.alz_architecture_definition.yaml*lib/architecture_definitions/fabrikam.alz_architecture_definition.json*terraform_architecture_file_path*"
        }

        It 'makes no change and warns when no user file declares the target architecture name' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: contoso'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
            $result.DefaultFileToRemove | Should -BeNullOrEmpty
            Should -Invoke -CommandName Write-ToConsoleLog -Times 1 -ParameterFilter { $IsWarning -and "$Messages" -like "*none has the architecture name 'alz_custom'*" }
        }

        It 'selects the same file on a rerun after the default was removed, using the starter variable default' {
            Remove-Item -Path $starterDefaultFile -Force
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: alz_custom'
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/sandbox.alz_architecture_definition.yaml') -Content 'name: sandbox'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -Be 'lib/architecture_definitions/contoso.alz_architecture_definition.yaml'
            $result.DefaultFileToRemove | Should -BeNullOrEmpty
        }

        It 'makes no change without a starter architecture name when user files have different names' {
            Remove-Item -Path $starterDefaultFile, (Join-Path $starterPath 'variables.management.tf') -Force
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: contoso'
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/sandbox.alz_architecture_definition.yaml') -Content 'name: sandbox'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
            Should -Invoke -CommandName Write-ToConsoleLog -ParameterFilter { $IsWarning -and "$Messages" -like '*could not tell which one*' }
        }

        It 'follows an architecture name the starter hardcodes over the input' {
            Remove-Item -Path (Join-Path $starterPath 'variables.management.tf') -Force
            Add-TestFile -Path (Join-Path $starterPath 'main.tf') -Content "module `"alz`" {`n  architecture_name = `"alz_custom`"`n}"
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: contoso'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath -architectureName 'contoso'

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
        }

        It 'ignores architecture files outside the library folder' {
            $file = Join-Path $root 'config/contoso.alz_architecture_definition.yaml'
            Add-TestFile -Path $file -Content 'name: alz_custom'
            $otherFolder = Join-Path $root 'config/templates'
            Add-TestFile -Path (Join-Path $otherFolder 'fabrikam.alz_architecture_definition.yaml') -Content 'name: alz_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($file, $otherFolder) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
            $result.DefaultFileToRemove | Should -BeNullOrEmpty
        }

        It 'ignores extensions in another case than the bootstrap reads' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.YAML') -Content 'name: alz_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
        }

        It 'compares the default path with the case rules of the file system' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/ALZ_custom.alz_architecture_definition.yaml') -Content 'name: alz_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            if ($IsWindows) {
                $result.ArchitectureFilePath | Should -BeNullOrEmpty
            } else {
                $result.ArchitectureFilePath | Should -Be 'lib/architecture_definitions/ALZ_custom.alz_architecture_definition.yaml'
            }
        }

        It 'skips files that cannot be read or whose name is not text' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/broken.alz_architecture_definition.yaml') -Content "name: [alz_custom`n  : :"
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/flag.alz_architecture_definition.yaml') -Content 'name: true'
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: alz_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -Be 'lib/architecture_definitions/contoso.alz_architecture_definition.yaml'
            Should -Invoke -CommandName Write-ToConsoleLog -Times 2 -ParameterFilter { $IsWarning -and "$Messages" -like 'Skipping architecture definition file*' }
        }

        It 'makes no change and warns when the powershell-yaml module is not available' {
            Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'ConvertFrom-Yaml' } -MockWith { $null }
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: alz_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
            Should -Invoke -CommandName Write-ToConsoleLog -Times 1 -ParameterFilter { $IsWarning -and "$Messages" -like '*powershell-yaml*' }
        }

        It 'keeps the default when the existing bootstrap manages a different root management group' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content "name: alz_custom`nmanagement_groups:`n  - id: contoso`n    parent_id: null"

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath -existingRootManagementGroupId 'alz'

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
            $result.DefaultFileToRemove | Should -BeNullOrEmpty
            Should -Invoke -CommandName Write-ToConsoleLog -Times 1 -ParameterFilter { $IsWarning -and "$Messages" -like "*manages the intermediate root management group 'alz'*'contoso'*" }
        }

        It 'switches when the existing bootstrap manages the same root management group' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content "name: alz_custom`nmanagement_groups:`n  - id: alz`n    parent_id: null"

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath -existingRootManagementGroupId 'alz'

            $result.ArchitectureFilePath | Should -Be 'lib/architecture_definitions/contoso.alz_architecture_definition.yaml'
            $result.DefaultFileToRemove | Should -Be $starterDefaultFile
        }

        It 'warns when the default file is missing and nothing replaces it' {
            Remove-Item -Path $starterDefaultFile -Force

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
            Should -Invoke -CommandName Write-ToConsoleLog -Times 1 -ParameterFilter { $IsWarning -and "$Messages" -like '*-replaceFiles*' }
        }
    }
}
