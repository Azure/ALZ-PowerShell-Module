function ConvertTo-DnsSafeTags {
    <#
    .SYNOPSIS
    Converts tags to DNS-safe format by removing spaces and parentheses from tag keys.
    
    .DESCRIPTION
    Azure DNS zones don't support the use of spaces or parentheses in tag keys, or tag keys that start with a number.
    This function sanitizes tag keys to make them DNS-safe.
    Reference: https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-resources
    
    .PARAMETER tags
    The hashtable or PSCustomObject containing tags to sanitize.
    
    .EXAMPLE
    ConvertTo-DnsSafeTags -tags @{"Business Application" = "ALZ"; "Owner" = "Platform"}
    Returns: @{"BusinessApplication" = "ALZ"; "Owner" = "Platform"}
    
    .EXAMPLE
    ConvertTo-DnsSafeTags -tags @{"Business Unit (Primary)" = "IT"; "1stTag" = "value"}
    Returns: @{"BusinessUnitPrimary" = "IT"; "_1stTag" = "value"}
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [object] $tags
    )
    
    if ($null -eq $tags) {
        return $null
    }
    
    $dnsSafeTags = @{}
    
    # Handle both hashtables and PSCustomObjects
    if ($tags -is [hashtable]) {
        foreach ($key in $tags.Keys) {
            $safeKey = $key -replace '\s+', ''  # Remove all whitespace
            $safeKey = $safeKey -replace '[()]', ''  # Remove parentheses
            # Ensure key doesn't start with a number by prepending underscore if needed
            if ($safeKey -match '^\d') {
                $safeKey = "_$safeKey"
            }
            if ($safeKey -ne "") {
                $dnsSafeTags[$safeKey] = $tags[$key]
            } else {
                Write-Warning "Tag key '$key' resulted in empty string after sanitization and was skipped"
            }
        }
    } elseif ($tags -is [PSCustomObject]) {
        foreach ($property in $tags.PSObject.Properties) {
            $safeKey = $property.Name -replace '\s+', ''  # Remove all whitespace
            $safeKey = $safeKey -replace '[()]', ''  # Remove parentheses
            # Ensure key doesn't start with a number by prepending underscore if needed
            if ($safeKey -match '^\d') {
                $safeKey = "_$safeKey"
            }
            if ($safeKey -ne "") {
                $dnsSafeTags[$safeKey] = $property.Value
            } else {
                Write-Warning "Tag key '$($property.Name)' resulted in empty string after sanitization and was skipped"
            }
        }
    } else {
        Write-Verbose "Tag format is neither hashtable nor PSCustomObject, returning as-is"
        return $tags
    }
    
    return $dnsSafeTags
}
