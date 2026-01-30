function Get-AzureContext {
    <#
    .SYNOPSIS
    Queries Azure for management groups, subscriptions, and regions available to the current user.
    .DESCRIPTION
    This function uses the Azure CLI to query for management groups, subscriptions, and regions
    that the currently logged-in user has access to. The results are returned as a hashtable
    containing arrays for use in interactive selection prompts.
    Only subscriptions from the current tenant are returned.
    Results are cached locally for 1 hour to improve performance.
    .PARAMETER OutputDirectory
    The output directory where the .cache folder will be created for storing the cached Azure context.
    .PARAMETER ClearCache
    When set, clears the cached Azure context and fetches fresh data from Azure.
    .OUTPUTS
    Returns a hashtable with the following keys:
    - ManagementGroups: Array of label/value objects for menu selection
    - Subscriptions: Array of label/value objects for menu selection
    - Regions: Array of label/value objects for menu selection (includes [AZ] indicator)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory,

        [Parameter(Mandatory = $false)]
        [switch]$ClearCache
    )

    # Define cache file path and expiration time (1 hour)
    $cacheFolder = Join-Path $OutputDirectory ".cache"
    $cacheFilePath = Join-Path $cacheFolder "azure-context-cache.json"
    $cacheExpirationHours = 24

    # Clear cache if requested
    if ($ClearCache.IsPresent -and (Test-Path $cacheFilePath)) {
        Remove-Item -Path $cacheFilePath -Force
        Write-ToConsoleLog "Azure context cache cleared." -IsSuccess
    }

    # Check if valid cache exists
    if (Test-Path $cacheFilePath) {
        $cacheFile = Get-Item $cacheFilePath
        $cacheAge = (Get-Date) - $cacheFile.LastWriteTime
        if ($cacheAge.TotalHours -lt $cacheExpirationHours) {
            try {
                $cachedContext = Get-Content -Path $cacheFilePath -Raw | ConvertFrom-Json -AsHashtable
                Write-ToConsoleLog "Using cached Azure context (cached $([math]::Round($cacheAge.TotalMinutes)) minutes ago). Use -clearCache to refresh."
                Write-ToConsoleLog "Found $($cachedContext.ManagementGroups.Count) management groups, $($cachedContext.Subscriptions.Count) subscriptions, and $($cachedContext.Regions.Count) regions"
                return $cachedContext
            } catch {
                Write-Verbose "Failed to read cache file, will fetch fresh data."
            }
        }
    }

    $azureContext = @{
        ManagementGroups = @()
        Subscriptions    = @()
        Regions          = @()
    }

    Write-ToConsoleLog "Querying Azure for management groups, subscriptions, and regions..."

    try {
        # Get the current tenant ID
        $tenantResult = az account show --query "tenantId" -o tsv 2>$null
        $currentTenantId = if ($LASTEXITCODE -eq 0 -and $tenantResult) { $tenantResult.Trim() } else { $null }

        # Get management groups
        $mgResult = az account management-group list --query "[].{id:name, displayName:displayName}" -o json 2>$null
        if ($LASTEXITCODE -eq 0 -and $mgResult) {
            $mgRaw = $mgResult | ConvertFrom-Json
            $azureContext.ManagementGroups = @($mgRaw | ForEach-Object {
                    @{
                        label = "$($_.displayName) ($($_.id))"
                        value = $_.id
                    }
                })
        } else {
            Write-ToConsoleLog "No management groups found or access denied." -IsWarning
        }

        # Get subscriptions (filtered to current tenant only, sorted by name)
        if ($null -ne $currentTenantId) {
            $subResult = az account list --query "sort_by([?tenantId=='$currentTenantId'].{id:id, name:name}, &name)" -o json 2>$null
        } else {
            $subResult = az account list --query "sort_by([].{id:id, name:name}, &name)" -o json 2>$null
        }
        if ($LASTEXITCODE -eq 0 -and $subResult) {
            $subRaw = $subResult | ConvertFrom-Json
            $azureContext.Subscriptions = @($subRaw | ForEach-Object {
                    @{
                        label = "$($_.name) ($($_.id))"
                        value = $_.id
                    }
                })
        } else {
            Write-ToConsoleLog "No subscriptions found or access denied." -IsWarning
        }

        # Get regions (sorted by displayName, include availability zone support)
        $regionResult = az account list-locations --query "sort_by([?metadata.regionType=='Physical'].{name:name, displayName:displayName, hasAvailabilityZones:length(availabilityZoneMappings || ``[]``) > ``0``}, &displayName)" -o json 2>$null
        if ($LASTEXITCODE -eq 0 -and $regionResult) {
            $regionRaw = $regionResult | ConvertFrom-Json
            $azureContext.Regions = @($regionRaw | ForEach-Object {
                    $azIndicator = if ($_.hasAvailabilityZones) { " [AZ]" } else { "" }
                    @{
                        label = "$($_.displayName) ($($_.name))$azIndicator"
                        value = $_.name
                    }
                })
        } else {
            Write-ToConsoleLog "No regions found or access denied." -IsWarning
        }

        Write-ToConsoleLog "Found $($azureContext.ManagementGroups.Count) management groups, $($azureContext.Subscriptions.Count) subscriptions, and $($azureContext.Regions.Count) regions"

        # Save to cache
        try {
            if (-not (Test-Path $cacheFolder)) {
                New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
            }
            $azureContext | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFilePath -Force
            Write-Verbose "Azure context cached to $cacheFilePath"
        } catch {
            Write-Verbose "Failed to write cache file: $_"
        }
    } catch {
        Write-ToConsoleLog "Could not query Azure resources. You will need to enter IDs manually." -IsWarning
    }

    return $azureContext
}
