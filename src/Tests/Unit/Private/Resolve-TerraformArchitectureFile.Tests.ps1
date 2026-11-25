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
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $starterPath = Join-Path $root 'starter'
            $userLibPath = Join-Path $root 'config/lib'
            $starterDefaultFile = Join-Path $starterPath 'lib/architecture_definitions/alz_custom.alz_architecture_definition.yaml'
            Add-TestFile -Path $starterDefaultFile -Content "name: alz_custom`nmanagement_groups: []"
            New-Item -Path $userLibPath -ItemType Directory -Force | Out-Null
        }

        It 'makes no change when the user lib has no architecture file' {
            Add-TestFile -Path (Join-Path $userLibPath 'archetype_definitions/root_custom.alz_archetype_override.yaml') -Content 'name: root_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
            $result.DefaultFileToRemove | Should -BeNullOrEmpty
        }

        It 'makes no change when the user architecture file replaces the default path' {
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/alz_custom.alz_architecture_definition.yaml') -Content 'name: alz_custom'

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
            Test-Path $starterDefaultFile | Should -BeTrue
        }

        It 'makes no change and warns when no user file declares the target architecture name' {
            Mock -CommandName Write-ToConsoleLog -MockWith { }
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: contoso'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -BeNullOrEmpty
            $result.DefaultFileToRemove | Should -BeNullOrEmpty
            Should -Invoke -CommandName Write-ToConsoleLog -Times 1 -ParameterFilter { $IsWarning -and "$Messages" -like '*alz_custom*' }
        }

        It 'selects the only user file when a previous run already removed the default' {
            Remove-Item -Path $starterDefaultFile -Force
            Add-TestFile -Path (Join-Path $userLibPath 'architecture_definitions/contoso.alz_architecture_definition.yaml') -Content 'name: alz_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($userLibPath) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -Be 'lib/architecture_definitions/contoso.alz_architecture_definition.yaml'
            $result.DefaultFileToRemove | Should -BeNullOrEmpty
        }

        It 'selects an architecture file passed directly as an additional file' {
            $file = Join-Path $root 'config/contoso.alz_architecture_definition.yaml'
            Add-TestFile -Path $file -Content 'name: alz_custom'

            $result = Resolve-TerraformArchitectureFile -starterModulePath $starterPath -starterAdditionalFiles @($file) -defaultArchitectureFilePath $defaultPath

            $result.ArchitectureFilePath | Should -Be 'contoso.alz_architecture_definition.yaml'
            $result.DefaultFileToRemove | Should -Be $starterDefaultFile
        }
    }
}
