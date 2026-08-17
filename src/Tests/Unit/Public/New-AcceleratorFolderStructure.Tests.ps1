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
    Describe 'New-AcceleratorFolderStructure Function Tests' -Tag Unit {
        BeforeEach {
            $script:copyOperations = @()
            Mock -CommandName git
            Mock -CommandName Copy-Item -MockWith {
                $script:copyOperations += [pscustomobject]@{
                    Path        = $Path
                    Destination = $Destination
                    Recurse     = $Recurse.IsPresent
                    Force       = $Force.IsPresent
                }
            }
            Mock -CommandName Write-ToConsoleLog
        }

        It 'copies bicep templates into the generated config folder' {
            $targetFolderPath = Join-Path $TestDrive 'accelerator'

            New-AcceleratorFolderStructure -iacType 'bicep' -targetFolderPath $targetFolderPath

            $templateCopy = $script:copyOperations | Where-Object {
                $_.Path -match '[/\\]templates$'
            }
            $templateCopy.Path | Should -HaveCount 1
            [System.IO.Path]::GetFileName($templateCopy.Path) | Should -Be 'templates'
            $templateCopy.Destination | Should -Be "$targetFolderPath/config"
            $templateCopy.Recurse | Should -BeTrue
            $templateCopy.Force | Should -BeTrue
        }
    }
}