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
            parameters = @(
                "parAzErGatewayAvailabilityZones.value",
                "parAzVpnGatewayAvailabilityZones.value",
                "parAzFirewallAvailabilityZones.value"
            )
        }
        [pscustomobject]@{
            source     = "vwanConnectivity.parameters.all.json";
            parameters = @("parVirtualWanHubs.value[0].parAzFirewallAvailabilityZones")
        }
    )

    foreach ($parametersFile in $parametersConfig) {
        $parametersFilePath = Join-Path -Path $alzEnvironmentDestination "config\custom-parameters\$($parametersFile.source)"
        if(!(Test-Path -Path $parametersFilePath)) {
            Write-Verbose -Message "The file $parametersFilePath does not exist, so skipping it..."
            continue
        }

        $parametersFileJsonContent = Get-Content -Path $parametersFilePath -Raw
        $bicepConfiguration = $parametersFileJsonContent | ConvertFrom-Json -AsHashtable

        $region = $bicepConfiguration.parameters.parLocation.value
        $zones = ($zonesSupport | Where-Object { $_.region -eq $region }).zones

        $parametersFile.parameters | ForEach-Object {
            $target = $_

            Write-Verbose "Attempting to update $($target) in $($parametersFile.source) with '$($zones)'"

            # Find the appropriate item which will be changed in the Bicep file.
            # Remove array '[' ']' characters so we can use the index value direct.
            $propertyNames = $target.Replace("[", ".").Replace("]", "").Replace("..", ".") -split "\."
            $bicepConfigNode = $bicepConfiguration.parameters
            $index = 0

            # Keep navigating into properties which the configuration specifies until we reach the bottom most object,
            #  e.g. not a value type - but the object reference so the value is persisted.
            do {
                if ($bicepConfigNode -is [array]) {
                    # If this is an array - use the property as an array index...
                    if ($propertyNames[$index] -match "[0-9]+" -eq $false) {
                        throw "Configuration specifies an array, but the index value '${$propertyNames[$index]}' is not a number"
                    }

                    $bicepConfigNode = $bicepConfigNode[$propertyNames[$index]]

                } elseif ($bicepConfigNode.ContainsKey($propertyNames[$index]) -eq $true) {
                    # We found the item, keep indexing into the object.
                    $bicepConfigNode = $bicepConfigNode[$propertyNames[$index]]
                } else {
                    # This property doesn't exist at this level in the hierarchy,
                    #  this isn't the property we're looking for, stop looking.
                    $bicepConfigNode = $null
                }

                ++$index

            } while (($null -ne $bicepConfigNode) -and ($index -lt $propertyNames.Length - 1))

            # If we're here, we can modify this file and we've got an actual object specified by the Name path value - and we can modify values on it.
            if ($null -ne $bicepConfigNode) {
                $leafPropertyName = $propertyNames[-1]
                Write-Verbose "Attempting to update $($target) in $($parametersFile.source) with '$($zones)'"
                $bicepConfigNode[$leafPropertyName] = $zones
            }
        }

        Write-Verbose "Updating Bicep parameter file: $parametersFilePath"
        ConvertTo-Json $bicepConfiguration -Depth 10 | Out-File $parametersFilePath
    }
}