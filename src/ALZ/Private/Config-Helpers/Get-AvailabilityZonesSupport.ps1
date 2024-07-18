function Get-AvailabilityZonesSupport {
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $region,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$zonesSupport
    )

    $zone = $zonesSupport | Where-Object { $_.region -eq $region }
    $jsonZones = ConvertTo-Json $zone.zones -Depth 10
    Write-Verbose "Zones for $region are $jsonZones"
    return $zone.zones
}