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
    Describe "Add-AvailabilityZonesBicepParameter" {
        BeforeAll {
            $alzEnvironmentDestination = "TestDrive:\"
            $hubParametersPath = "https://raw.githubusercontent.com/Azure/ALZ-Bicep/main/infra-as-code/bicep/modules/hubNetworking/parameters/hubNetworking.parameters.all.json"
            Invoke-WebRequest -Uri $hubParametersPath -OutFile "$alzEnvironmentDestination\hubNetworking.parameters.all.json"
        }
        Context "Hub networking parameters availability zones check" {
            BeforeAll {
                Mock -CommandName Join-Path -MockWith {
                    $alzEnvironmentDestination + "\hubNetworking.parameters.all.json"
                }
                Mock -CommandName Get-Content -ParameterFilter { $Path -contains 'parametersFilePath' } -MockWith {
                    Get-Content -Path "TestDrive:\hubNetworking.parameters.all.json"
                }
            }
            It "Should add 3 availability zones for hub networking parameters" {
                Add-AvailabilityZonesBicepParameter -alzEnvironmentDestination $alzEnvironmentDestination -configFile ([PSCustomObject]@{
                        zonesSupport = @(
                            [PSCustomObject]@{
                                region = "eastus"
                                zones  = @("1", "2", "3")
                            }
                        )
                    })
                $parametersFileJsonContent = Get-Content -Path "TestDrive:\hubNetworking.parameters.all.json" -Raw
                $jsonObject = $parametersFileJsonContent | ConvertFrom-Json
                $jsonObject.parameters.parAzErGatewayAvailabilityZones.value | Should -Be @("1", "2", "3")
                $jsonObject.parameters.parAzVpnGatewayAvailabilityZones.value | Should -Be @("1", "2", "3")
                $jsonObject.parameters.parAzFirewallAvailabilityZones.value | Should -Be @("1", "2", "3")
            }
            It "Should add 2 availability zones for hub networking parameters" {
                Add-AvailabilityZonesBicepParameter -alzEnvironmentDestination $alzEnvironmentDestination -configFile ([PSCustomObject]@{
                        zonesSupport = @(
                            [PSCustomObject]@{
                                region = "eastus"
                                zones  = @("1", "2")
                            }
                        )
                    })
                $parametersFileJsonContent = Get-Content -Path "TestDrive:\hubNetworking.parameters.all.json" -Raw
                $jsonObject = $parametersFileJsonContent | ConvertFrom-Json
                $jsonObject.parameters.parAzErGatewayAvailabilityZones.value | Should -Be @("1", "2")
                $jsonObject.parameters.parAzVpnGatewayAvailabilityZones.value | Should -Be @("1", "2")
                $jsonObject.parameters.parAzFirewallAvailabilityZones.value | Should -Be @("1", "2")
            }
            It "Should add 0 availability zones for hub networking parameters" {
                Add-AvailabilityZonesBicepParameter -alzEnvironmentDestination $alzEnvironmentDestination -configFile ([PSCustomObject]@{
                        zonesSupport = @(
                            [PSCustomObject]@{
                                region = "eastus"
                                zones  = @()
                            }
                        )
                    })
                $parametersFileJsonContent = Get-Content -Path "TestDrive:\hubNetworking.parameters.all.json" -Raw
                $jsonObject = $parametersFileJsonContent | ConvertFrom-Json
                $jsonObject.parameters.parAzErGatewayAvailabilityZones.value | Should -Be @()
                $jsonObject.parameters.parAzVpnGatewayAvailabilityZones.value | Should -Be @()
                $jsonObject.parameters.parAzFirewallAvailabilityZones.value | Should -Be @()
            }
        }
    }

}