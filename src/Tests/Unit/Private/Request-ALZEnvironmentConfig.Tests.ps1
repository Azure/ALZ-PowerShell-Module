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
   Describe 'Request-ALZEnvironmentConfig Private Function Tests' -Tag Unit {
      BeforeAll {
         $WarningPreference = 'SilentlyContinue'
         $ErrorActionPreference = 'SilentlyContinue'
      }
      Context 'Request-ALZEnvironmentConfig should request CLI input for configuration.' {
         It 'Based on the configuration object' {

            Mock -CommandName Request-ConfigurationValue

            $config = @'
                {
                    "parameters":{
                       "Prefix":{
                          "Type":"UserInput",
                          "Description":"The prefix that will be added to all resources created by this deployment. (e.g. 'alz')",
                          "Targets":[
                             {
                                "Name":"parTopLevelManagementGroupPrefix",
                                "Destination":"Parameters"
                             }
                          ],
                          "DefaultValue":"alz"
                       }
                    }
                 }
'@ | ConvertFrom-Json

            Request-ALZEnvironmentConfig -configurationParameters $config.Parameters

            Should -Invoke Request-ConfigurationValue -Scope It -Times 1 -Exactly
         }

      }
   }
}