function Add-AvailabilityZonesBicepParameter {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$zonesSupport
    )

    $parametersConfig = @(
        [pscustomobject]@{
            source     = "hubNetworking.parameters.all.json";
            parameters = "parAzErGatewayAvailabilityZones,parAzVpnGatewayAvailabilityZones,parAzFirewallAvailabilityZones"
        }
        [pscustomobject]@{
            source     = "vwanConnectivity.parameters.all.json";
            parameters = "parAzFirewallAvailabilityZones"
        }
    )

    foreach ($parametersFile in $parametersConfig) {
        $parametersFilePath = Join-Path -Path $alzEnvironmentDestination "config\custom-parameters\$($parametersFile.source)"
        $region = (Get-Content $parametersFilePath | ConvertFrom-Json).parameters.parLocation.Value
        $zones = ($zonesSupport | Where-Object { $_.region -eq $region }).zones
        $parametersFileJsonContent = Get-Content -Path $parametersFilePath -Raw
        $jsonObject = $parametersFileJsonContent | ConvertFrom-Json
        $parametersFile.parameters.Split(",") | ForEach-Object {
            $parameter = $_
            try {
                if ($null -eq $jsonObject.parameters.$parameter.value) {
                    $jsonObject.parameters.$parameter.value = @($zones)
                }

                else {
                    $jsonObject.parameters.$parameter.value = $zones
                }

            }

            catch {
                Write-Error -Message "The parameter $parameter does not exist in the file $parametersFilePath"
            }
        }
        $parametersFileJsonContent = $jsonObject | ConvertTo-Json -Depth 10
        Set-Content -Path $parametersFilePath -Value $parametersFileJsonContent
    }
}