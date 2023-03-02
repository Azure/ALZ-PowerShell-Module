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
    Describe 'Get-HellowWorld Public Function Tests' -Tag Unit {
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
                Mock -CommandName Get-Day -MockWith {
                    'Friday'
                } #endMock
            } #beforeEach

            It 'should return the expected results' {
                Get-HelloWorld | Should -BeExactly 'Hello, happy Friday World!'
            } #it

        } #context_Success
    } #describe_Get-HellowWorld
} #inModule
