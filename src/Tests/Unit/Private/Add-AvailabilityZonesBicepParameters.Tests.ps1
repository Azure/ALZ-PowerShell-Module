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
    $VerbosePreference = "Continue"
    Describe "Add-AvailabilityZonesBicepParameter" {
        BeforeAll {
            $alzEnvironmentDestination = "TestDrive:\"
            $hubParametersPath = "https://raw.githubusercontent.com/Azure/ALZ-Bicep/main/infra-as-code/bicep/modules/hubNetworking/parameters/hubNetworking.parameters.all.json"
            New-Item -Path "$alzEnvironmentDestination\config\custom-parameters" -Force -ItemType Directory
            Invoke-WebRequest -Uri $hubParametersPath -OutFile "$alzEnvironmentDestination\config\custom-parameters\hubNetworking.parameters.all.json"
        }
        Context "Hub networking parameters availability zones check" {
            It "Should add 3 availability zones for hub networking parameters" {
                Add-AvailabilityZonesBicepParameter -alzEnvironmentDestination $alzEnvironmentDestination -zonesSupport (@(
                            [PSCustomObject]@{
                                region = "eastus"
                                zones  = @("1", "2", "3")
                            }
                        )
                    )
                $parametersFileJsonContent = Get-Content -Path "TestDrive:\config\custom-parameters\hubNetworking.parameters.all.json" -Raw
                Write-Verbose (Test-Path -Path "TestDrive:\config\custom-parameters\hubNetworking.parameters.all.json")
                #Write-Verbose $parametersFileJsonContent
                $jsonObject = $parametersFileJsonContent | ConvertFrom-Json
                $jsonObject.parameters.parAzErGatewayAvailabilityZones.value | Should -Be @("1", "2", "3")
                $jsonObject.parameters.parAzVpnGatewayAvailabilityZones.value | Should -Be @("1", "2", "3")
                $jsonObject.parameters.parAzFirewallAvailabilityZones.value | Should -Be @("1", "2", "3")
            }
            It "Should add 2 availability zones for hub networking parameters" {
                Add-AvailabilityZonesBicepParameter -alzEnvironmentDestination $alzEnvironmentDestination -zonesSupport (@(
                            [PSCustomObject]@{
                                region = "eastus"
                                zones  = @("1", "2")
                            }
                        )
                    )
                $parametersFileJsonContent = Get-Content -Path "TestDrive:\config\custom-parameters\hubNetworking.parameters.all.json" -Raw
                $jsonObject = $parametersFileJsonContent | ConvertFrom-Json
                $jsonObject.parameters.parAzErGatewayAvailabilityZones.value | Should -Be @("1", "2")
                $jsonObject.parameters.parAzVpnGatewayAvailabilityZones.value | Should -Be @("1", "2")
                $jsonObject.parameters.parAzFirewallAvailabilityZones.value | Should -Be @("1", "2")
            }
            It "Should add 0 availability zones for hub networking parameters" {
                Add-AvailabilityZonesBicepParameter -alzEnvironmentDestination $alzEnvironmentDestination -zonesSupport (@(
                            [PSCustomObject]@{
                                region = "eastus"
                                zones  = @()
                            }
                        )
                    )
                $parametersFileJsonContent = Get-Content -Path "TestDrive:\config\custom-parameters\hubNetworking.parameters.all.json" -Raw
                $jsonObject = $parametersFileJsonContent | ConvertFrom-Json
                $jsonObject.parameters.parAzErGatewayAvailabilityZones.value | Should -Be @()
                $jsonObject.parameters.parAzVpnGatewayAvailabilityZones.value | Should -Be @()
                $jsonObject.parameters.parAzFirewallAvailabilityZones.value | Should -Be @()
            }
        }
    }

}