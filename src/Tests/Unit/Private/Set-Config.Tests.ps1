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
    Describe 'Set-Config Private Function Tests' -Tag Unit {
        BeforeAll {
            $WarningPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'SilentlyContinue'
        }
        Context 'Set-Config should request CLI input for configuration.' {
            It 'Based on the configuration object' {

                $config = @'
                {
                    "parameters": {
                        "Prefix": {
                            "Type": "UserInput",
                            "Description": "The prefix that will be added to all resources created by this deployment. (e.g. 'alz')",
                            "Targets": [
                                {
                                    "Name": "parTopLevelManagementGroupPrefix",
                                    "Destination": "Parameters"
                                }
                            ],
                            "DefaultValue": "alz",
                            "Value": ""
                        }
                    }
                }
'@ | ConvertFrom-Json

                Set-Config -configurationParameters $config.Parameters
            }

        }
    }
}
