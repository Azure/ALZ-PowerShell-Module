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
    Describe "Edit-LineEnding" {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context "When converting to Unix line endings" {
            It "Converts Windows line endings to Unix" {
                $inputText = "Hello`r`nWorld`r`n"
                $expectedOutput = "Hello`nWorld`n"
                $result = Edit-LineEnding -InputText $inputText -LineEnding Unix
                $result | Should -Be $expectedOutput
            }

            It "Converts mixed line endings to Unix" {
                $inputText = "Hello`rWorld`n"
                $expectedOutput = "Hello`nWorld`n"
                $result = Edit-LineEnding -InputText $inputText -LineEnding Unix
                $result | Should -Be $expectedOutput
            }

            It "Does not modify Unix line endings" {
                $inputText = "Hello`nWorld`n"
                $expectedOutput = "Hello`nWorld`n"
                $result = Edit-LineEnding -InputText $inputText -LineEnding Unix
                $result | Should -Be $expectedOutput
            }
        }

        Context "When converting to Windows line endings" {
            It "Converts Unix line endings to Windows" {
                $inputText = "Hello`nWorld`n"
                $expectedOutput = "Hello`r`nWorld`r`n"
                $result = Edit-LineEnding -InputText $inputText -LineEnding Win
                $result | Should -Be $expectedOutput
            }

            It "Converts mixed line endings to Windows" {
                $inputText = "Hello`rWorld`n"
                $expectedOutput = "Hello`r`nWorld`r`n"
                $result = Edit-LineEnding -InputText $inputText -LineEnding Win
                $result | Should -Be $expectedOutput
            }

            It "Does not modify Windows line endings" {
                $inputText = "Hello`r`nWorld`r`n"
                $expectedOutput = "Hello`r`nWorld`r`n"
                $result = Edit-LineEnding -InputText $inputText -LineEnding Win
                $result | Should -Be $expectedOutput
            }
        }

        Context "When converting to Darwin line endings" {
            It "Converts Unix line endings to Darwin" {
                $inputText = "Hello`nWorld`n"
                $expectedOutput = "Hello`rWorld`r"
                $result = Edit-LineEnding -InputText $inputText -LineEnding Darwin
                $result | Should -Be $expectedOutput
            }

            It "Converts mixed line endings to Darwin" {
                $inputText = "Hello`rWorld`n"
                $expectedOutput = "Hello`rWorld`r"
                $result = Edit-LineEnding -InputText $inputText -LineEnding Darwin
                $result | Should -Be $expectedOutput
            }

            It "Does not modify Darwin line endings" {
                $inputText = "Hello`rWorld`r"
                $expectedOutput = "Hello`rWorld`r"
                $result = Edit-LineEnding -InputText $inputText -LineEnding Darwin
                $result | Should -Be $expectedOutput
            }
        }
    }
}