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
    Describe 'New-ALZEnvironment Public Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        } #beforeAll
        Context 'Error' {

            # It 'should ...' {

            # } #it

        } #context_Error
        Context 'Success' {

            BeforeEach {
                Mock -CommandName Request-ALZEnvironmentConfig -MockWith {
                    @(
                        @{
                            "description"  = "Test configuration1"
                            "names"        = @("value1", "value2")
                            "defaultValue" = "default"
                            "value"        = "value"
                        },
                        @{
                            "description"  = "Test configuration2"
                            "names"        = @("value1")
                            "defaultValue" = "default"
                            "value"        = "value"
                        }
                    )
                } #endMock

                Mock -CommandName Edit-ALZConfigurationFilesInPlace
            } #beforeEach

            It 'should return the output directory on completion' {
                $result = New-ALZEnvironment
                $result[0].description | Should -BeExactly "Test configuration1"
                $result[0].names[0] | Should -BeExactly "value1"
                $result[0].names[1] | Should -BeExactly "value2"
                $result[0].defaultValue | Should -BeExactly "default"
                $result[0].value | Should -BeExactly "value"
            }

        } #context_Success
    } #describe_Get-HellowWorld
} #inModule
