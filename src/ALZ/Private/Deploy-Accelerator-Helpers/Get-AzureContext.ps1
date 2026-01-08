function Get-AzureContext {
    <#
    .SYNOPSIS
    Queries Azure for management groups and subscriptions available to the current user.
    .DESCRIPTION
    This function uses the Azure CLI to query for management groups and subscriptions
    that the currently logged-in user has access to. The results are returned as a hashtable
    containing arrays of management groups and subscriptions for use in interactive selection prompts.
    Only subscriptions from the current tenant are returned.
    .OUTPUTS
    Returns a hashtable with the following keys:
    - ManagementGroups: Array of objects with id and displayName properties
    - Subscriptions: Array of objects with id and name properties
    #>
    [CmdletBinding()]
    param()

    $azureContext = @{
        ManagementGroups = @()
        Subscriptions    = @()
    }

    Write-InformationColored "Querying Azure for management groups and subscriptions..." -ForegroundColor Green -InformationAction Continue

    try {
        # Get the current tenant ID
        $tenantResult = az account show --query "tenantId" -o tsv 2>$null
        $currentTenantId = if ($LASTEXITCODE -eq 0 -and $tenantResult) { $tenantResult.Trim() } else { $null }

        # Get management groups
        $mgResult = az account management-group list --query "[].{id:name, displayName:displayName}" -o json 2>$null
        if ($LASTEXITCODE -eq 0 -and $mgResult) {
            $azureContext.ManagementGroups = $mgResult | ConvertFrom-Json
        }

        # Get subscriptions (filtered to current tenant only, sorted by name)
        if ($null -ne $currentTenantId) {
            $subResult = az account list --query "sort_by([?tenantId=='$currentTenantId'].{id:id, name:name}, &name)" -o json 2>$null
        } else {
            $subResult = az account list --query "sort_by([].{id:id, name:name}, &name)" -o json 2>$null
        }
        if ($LASTEXITCODE -eq 0 -and $subResult) {
            $azureContext.Subscriptions = $subResult | ConvertFrom-Json
        }

        Write-InformationColored "  Found $($azureContext.ManagementGroups.Count) management groups and $($azureContext.Subscriptions.Count) subscriptions" -ForegroundColor Gray -InformationAction Continue
    } catch {
        Write-InformationColored "  Warning: Could not query Azure resources. You will need to enter IDs manually." -ForegroundColor Yellow -InformationAction Continue
    }

    return $azureContext
}
