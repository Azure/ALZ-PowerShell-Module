function Set-DnsSafeTagsForVirtualHubs {
    <#
    .SYNOPSIS
    Processes virtual_hubs configuration to ensure DNS zone tags are DNS-safe.
    
    .DESCRIPTION
    This function processes the virtual_hubs configuration object and sanitizes tags for private_dns_zones
    to ensure they don't contain spaces or other characters not supported by Azure DNS.
    Implements fallback logic: private_dns_zones.tags -> connectivity_tags -> overall tags (all sanitized)
    
    .PARAMETER virtualHubs
    The virtual_hubs configuration object to process.
    
    .PARAMETER connectivityTags
    Optional connectivity-level tags to use as fallback.
    
    .PARAMETER overallTags
    Optional overall/global tags to use as final fallback.
    
    .EXAMPLE
    Set-DnsSafeTagsForVirtualHubs -virtualHubs $config -connectivityTags @{"Business Unit" = "IT"}
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [object] $virtualHubs,
        
        [Parameter(Mandatory = $false)]
        [object] $connectivityTags = $null,
        
        [Parameter(Mandatory = $false)]
        [object] $overallTags = $null
    )
    
    if ($null -eq $virtualHubs) {
        return $virtualHubs
    }
    
    # Process each virtual hub
    foreach ($hubProperty in $virtualHubs.PSObject.Properties) {
        $hub = $hubProperty.Value
        
        if ($null -eq $hub) {
            continue
        }
        
        # Check if this hub has private_dns_zones configuration
        $privateDnsZonesProperty = $hub.PSObject.Properties | Where-Object { $_.Name -eq "private_dns_zones" }
        
        if ($null -ne $privateDnsZonesProperty) {
            $privateDnsZones = $privateDnsZonesProperty.Value
            
            if ($null -ne $privateDnsZones) {
                # Check if DNS zone has its own tags
                $dnsTagsProperty = $privateDnsZones.PSObject.Properties | Where-Object { $_.Name -eq "tags" }
                
                if ($null -ne $dnsTagsProperty -and $null -ne $dnsTagsProperty.Value) {
                    # DNS zone has its own tags - sanitize them
                    Write-Verbose "Sanitizing DNS zone tags for hub: $($hubProperty.Name)"
                    $sanitizedTags = ConvertTo-DnsSafeTags -tags $dnsTagsProperty.Value
                    $privateDnsZones.tags = $sanitizedTags
                } else {
                    # No DNS-specific tags, implement fallback logic
                    Write-Verbose "No DNS-specific tags found for hub: $($hubProperty.Name), applying fallback logic"
                    
                    $tagsToUse = $null
                    
                    # Try connectivity tags first
                    if ($null -ne $connectivityTags) {
                        Write-Verbose "Using connectivity tags as fallback"
                        $tagsToUse = $connectivityTags
                    }
                    # Fall back to overall tags if connectivity tags not available
                    elseif ($null -ne $overallTags) {
                        Write-Verbose "Using overall tags as fallback"
                        $tagsToUse = $overallTags
                    }
                    
                    # Sanitize and apply the fallback tags
                    if ($null -ne $tagsToUse) {
                        $sanitizedTags = ConvertTo-DnsSafeTags -tags $tagsToUse
                        
                        # Add tags property if it doesn't exist
                        if ($null -eq $dnsTagsProperty) {
                            $privateDnsZones | Add-Member -NotePropertyName "tags" -NotePropertyValue $sanitizedTags -Force
                        } else {
                            $privateDnsZones.tags = $sanitizedTags
                        }
                    }
                }
            }
        }
    }
    
    return $virtualHubs
}
