function Remove-PlatformLandingZone {
    <#
    .SYNOPSIS
        Removes Azure Landing Zone platform resources including management groups, subscriptions, and resource groups.

    .DESCRIPTION
        The Remove-PlatformLandingZone function performs a comprehensive cleanup of Azure Landing Zone platform resources.
        It recursively deletes management groups, removes subscriptions from management groups, and deletes all resource
        groups within specified subscriptions. This function is primarily designed for testing and cleanup scenarios.

        The function operates in the following sequence:
        1. Identifies and retrieves management groups based on the specified prefix and range
        2. Recursively discovers all child management groups in the hierarchy
        3. Removes subscriptions from management groups (starting from the deepest level)
        4. Deletes management groups in reverse depth order (children before parents)
        5. Deletes all resource groups within the specified subscriptions

        WARNING: This is a destructive operation that will permanently delete Azure resources. Use with extreme caution
        and ensure you have appropriate backups and authorization before executing.

    .PARAMETER managementGroupsPrefix
        The prefix used for management group names. The function will search for management groups matching the pattern
        "{prefix}-{number}" where number is formatted as a two-digit integer.
        Default value: "alz-acc-avm-test"

    .PARAMETER managementGroupStartNumber
        The starting index number for management group enumeration. This is the first number in the sequence of
        management groups to be processed.
        Default value: 1

    .PARAMETER managementGroupCount
        The number of management groups to process, starting from the managementGroupStartNumber. For example, if
        managementGroupStartNumber is 1 and managementGroupCount is 11, management groups 1-11 will be processed.
        Default value: 11

    .PARAMETER subscriptionNamePrefix
        The prefix used for subscription names. The function will search for subscriptions matching the pattern
        "{prefix}{number}{postfix}" where number is formatted as a two-digit integer.
        Default value: "alz-acc-avm-test-"

    .PARAMETER subscriptionStartNumber
        The starting index number for subscription enumeration. This is the first number in the sequence of
        subscriptions to be processed.
        Default value: 1

    .PARAMETER subscriptionCount
        The number of subscription indices to process, starting from the subscriptionStartNumber. Each index is
        combined with all subscription postfixes to form complete subscription names.
        Default value: 11

    .PARAMETER subscriptionPostfixes
        An array of subscription name postfixes to append to the subscription name pattern. Each combination of
        subscriptionNamePrefix, number, and postfix creates a unique subscription name to process.
        Default value: @("-connectivity", "-management", "-identity", "-security")

    .EXAMPLE
        Remove-PlatformLandingZone

        Removes platform landing zone resources using all default parameter values. This will process management
        groups from "alz-acc-avm-test-01" through "alz-acc-avm-test-11" and subscriptions matching patterns like
        "alz-acc-avm-test-01-connectivity", "alz-acc-avm-test-01-management", etc.

    .EXAMPLE
        Remove-PlatformLandingZone -managementGroupsPrefix "my-alz" -managementGroupCount 5

        Removes platform landing zone resources using a custom management group prefix and processing only 5
        management groups (my-alz-01 through my-alz-05).

    .EXAMPLE
        Remove-PlatformLandingZone -subscriptionNamePrefix "myorg-test-" -subscriptionPostfixes @("-conn", "-mgmt")

        Removes platform landing zone resources using a custom subscription naming pattern with only two postfixes.
        This will process subscriptions like "myorg-test-01-conn", "myorg-test-01-mgmt", etc.

    .EXAMPLE
        Remove-PlatformLandingZone -managementGroupStartNumber 5 -managementGroupCount 3 -subscriptionStartNumber 5 -subscriptionCount 3

        Removes a specific range of platform landing zone resources, processing management groups 5-7 and
        subscriptions 5-7 with all default postfixes.

    .NOTES
        This function uses Azure CLI commands and requires:
        - Azure CLI to be installed and available in the system path
        - User to be authenticated to Azure (az login)
        - Appropriate permissions to delete management groups, manage subscriptions, and delete resource groups

        The function uses parallel processing with ForEach-Object -Parallel to improve performance when handling
        multiple management groups and subscriptions. The default throttle limit is set to 11 for management groups
        and 10 for resource group deletions.

        Resource group deletions include retry logic to handle dependencies between resources. If a resource group
        fails to delete, it will be retried after other resource groups in the same subscription have completed.

    .LINK
        https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/

    .LINK
        https://learn.microsoft.com/cli/azure/account/management-group
    #>
    [CmdletBinding()]
    param (
        [string[]]$managementGroups,
        [string[]]$subscriptions = @(),
        [string[]]$resourceGroupsToRetainNamePatterns = @(),
        [switch]$bypassConfirmation,
        [int]$throttleLimit = 11
    )

    function Get-ManagementGroupChildrenRecursive {
        param (
            [object[]]$managementGroups,
            [int]$depth = 0,
            [hashtable]$managementGroupsFound = @{}
        )

        foreach($managementGroup in $managementGroups) {
            if(!$managementGroupsFound.ContainsKey($depth)) {
                $managementGroupsFound[$depth] = @()
            }

            $managementGroupsFound[$depth] += $managementGroup.name

            $children = $managementGroup.children | Where-Object { $_.type -eq "Microsoft.Management/managementGroups" }

            if ($children -and $children.Count -gt 0) {
                Write-Host "Management group has children: $($managementGroup.name)"
                if(!$managementGroupsFound.ContainsKey($depth + 1)) {
                    $managementGroupsFound[$depth + 1] = @()
                }
                Get-ManagementGroupChildrenRecursive -managementGroups $children -depth ($depth + 1) -managementGroupsFound $managementGroupsFound
            } else {
                Write-Host "Management group has no children: $($managementGroup.name)"
            }
        }

        if($depth -eq 0) {
        return $managementGroupsFound
        }
    }

    function Test-IsGuid
    {
        [OutputType([bool])]
        param
        (
            [Parameter(Mandatory = $true)]
            [string]$StringGuid
        )

        $ObjectGuid = [System.Guid]::empty
        return [System.Guid]::TryParse($StringGuid,[System.Management.Automation.PSReference]$ObjectGuid)
    }

    $funcDef = ${function:Get-ManagementGroupChildrenRecursive}.ToString()
    $subscriptionsProvided = $subscriptions.Count -gt 0
    if($subscriptionsProvided) {
        Write-Host "Subscriptions have been provided, checking they exist. We will not discover additional subscriptions from management groups." -ForegroundColor Yellow
    } else {
        Write-Host "No subscriptions provided, discovering subscriptions from management groups." -ForegroundColor Yellow
    }

    $subscriptionsFound = [System.Collections.Concurrent.ConcurrentBag[hashtable]]::new()

    foreach($subscription in $subscriptions) {
        $subscriptionObject = @{
            Id = Test-IsGuid -StringGuid $subscription ? $subscription : (az account list --all --query "[?name=='$subscription'].id" -o tsv)
            Name = Test-IsGuid -StringGuid $subscription ? (az account list --all --query "[?id=='$subscription'].name" -o tsv) : $subscription
        }
        if(-not $subscriptionObject.Id -or -not $subscriptionObject.Name) {
            Write-Host "Subscription not found, skipping: $($subscription.Name) (ID: $($subscription.Id))" -ForegroundColor Orange
            continue
        }
        $subscriptionsFound.Add($subscriptionObject)
    }

    $managementGroups | ForEach-Object -Parallel {

        $subscriptionsProvided = $using:subscriptionsProvided
        $subscriptionsFound = $using:subscriptionsFound

        $managementGroupId = $_

        Write-Host "Finding management group: $managementGroupId"
        $topLevelManagementGroup = (az account management-group show --name $managementGroupId --expand --recurse) | ConvertFrom-Json

        $hasChildren = $topLevelManagementGroup.children -and $topLevelManagementGroup.children.Count -gt 0

        $managementGroupsToDelete = @{}

        if($hasChildren) {
            ${function:Get-ManagementGroupChildrenRecursive} = $using:funcDef
            $managementGroupsToDelete = Get-ManagementGroupChildrenRecursive -managementGroups @($topLevelManagementGroup.children)
        } else {
            Write-Host "Management group has no children: $managementGroupId"
        }

        $reverseKeys = $managementGroupsToDelete.Keys | Sort-Object -Descending
        foreach($depth in $reverseKeys) {
            $managementGroups = $managementGroupsToDelete[$depth]

            Write-Host "Deleting management groups at depth: $depth"

            $managementGroups | ForEach-Object -Parallel {
                $subscriptions = (az account management-group subscription show-sub-under-mg --name $_) | ConvertFrom-Json
                if ($subscriptions.Count -gt 0) {
                    Write-Host "Management group has subscriptions: $_"
                    foreach ($subscription in $subscriptions) {
                        Write-Host "Removing subscription from management group: $_, subscription: $($subscription.displayName)"
                        if(-not $subscriptionsProvided) {
                            $subscriptionsFound.Add(@{
                                Id   = $subscription.name
                                Name = $subscription.displayName
                            })
                        }
                        az account management-group subscription remove --name $_ --subscription $subscription.name
                    }
                } else {
                    Write-Host "Management group has no subscriptions: $_"
                }

                Write-Host "Deleting management group: $_"
                az account management-group delete --name $_
            } -ThrottleLimit $using:throttleLimit
        }
    } -ThrottleLimit $throttleLimit

    $subscriptionsFinal = $subscriptionsFound.ToArray() | Sort-Object -Property name -Unique

    if($subscriptionsFinal.Count -eq 0) {
        Write-Host "No subscriptions provided or found, skipping resource group deletion."
        return
    } else {
        if(-not $bypassConfirmation) {
            Write-Host "The following Subscriptions were provided or discovered during management group cleanup:"
            $subscriptionsFinal | ForEach-Object { Write-Host "Name: $($_.Name), ID: $($_.Id)" }
            Write-Host ""
            $confirmationText = "I CONFIRM I UNDERSTAND ALL THE RESOURCES IN THE NAMED SUBSCRIPTIONS WILL BE PERMANENTLY DELETED"
            Write-Host "WARNING: This operation will permanently DELETE ALL RESOURCE GROUPS in the above subscriptions!" -ForegroundColor Red
            Write-Host "If you wish to proceed, type '$confirmationText' to confirm." -ForegroundColor Red
            $confirmation = Read-Host "Enter the confirmation text"
            if ($confirmation -ne $confirmationText) {
                Write-Host "Confirmation not received. Exiting without deleting resource groups."
                return
            }
            Write-Host "WARNING: This operation operation is permanent cannot be reversed!" -ForegroundColor Red
            Write-Host "Are you sure you want to proceed? Type 'YES' to delete all your resources..." -ForegroundColor Red
            $finalConfirmation = Read-Host "Type 'YES' to confirm"
            if ($finalConfirmation -ne "YES") {
                Write-Host "Final confirmation not received. Exiting without deleting resource groups."
                return
            }
            Write-Host "Final confirmation received. Proceeding with resource group deletion..." -ForegroundColor Green
        }
    }

    $subscriptionsFinal | ForEach-Object -Parallel {
        $subscription = $_
        Write-Host "Finding resource groups for subscription: $($subscription.Name) (ID: $($subscription.Id))"

        $resourceGroups = (az group list --subscription $subscription.Id) | ConvertFrom-Json

        if ($resourceGroups.Count -eq 0) {
            Write-Host "No resource groups found for subscription: $($subscription.Name) (ID: $($subscription.Id)), skipping."
            continue
        }

        Write-Host "Found resource groups for subscription: $($subscription.Name) (ID: $($subscription.Id)), count: $($resourceGroups.Count)"

        $resourceGroupsToDelete = @()
        $resourceGroupsToRetainNamePatterns = $using:resourceGroupsToRetainNamePatterns

        foreach ($resourceGroup in $resourceGroups) {
            $foundMatch = $false

            foreach ($pattern in $resourceGroupsToRetainNamePatterns) {
                if ($resourceGroup.name -match $pattern) {
                    Write-Host "Retaining resource group as it matches the pattern '$pattern': $($resourceGroup.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))" -ForegroundColor Yellow
                    $foundMatch = $true
                    break
                }
            }

            if($foundMatch) {
                continue
            }

            $resourceGroupsToDelete += @{
                ResourceGroupName = $resourceGroup.name
                Subscription = $subscription
            }
        }

        $shouldRetry = $true

        while($shouldRetry) {
            $shouldRetry = $false
            $resourceGroupsToRetry = [System.Collections.Concurrent.ConcurrentBag[hashtable]]::new()
            $resourceGroupsToDelete | ForEach-Object -Parallel {
                $resourceGroupName = $_.ResourceGroupName
                $subscription = $_.Subscription

                Write-Host "Deleting resource group for subscription: $($subscription.Name) (ID: $($subscription.Id)), resource group: $($ResourceGroupName)"
                $result = az group delete --name $ResourceGroupName --subscription $subscription.Id --yes 2>&1

                if (!$result) {
                    Write-Host "Deleted resource group for subscription: $($subscription.Name) (ID: $($subscription.Id)), resource group: $($ResourceGroupName)"
                } else {
                    Write-Host "Delete resource group failed for subscription: $($subscription.Name) (ID: $($subscription.Id)), resource group: $($ResourceGroupName)"
                    Write-Host "It will be retried once the other resource groups in the subscription have reported their status."
                    Write-Verbose "$result"
                    $retries = $using:resourceGroupsToRetry
                    $retries.Add($_)
                }
            } -ThrottleLimit $using:throttleLimit

            if($resourceGroupsToRetry.Count -gt 0) {
                Write-Host "Some resource groups failed to delete and will be retried in subscription: $($subscription.Name) (ID: $($subscription.Id))"
                $shouldRetry = $true
                $resourceGroupsToDelete = $resourceGroupsToRetry.ToArray()
            } else {
                Write-Host "All resource groups deleted successfully in subscription: $($subscription.Name) (ID: $($subscription.Id))."
            }
        }

        Write-Host "Checking for Microsoft Defender for Cloud Plans to reset in subscription: $($subscription.Name) (ID: $($subscription.Id))"
        $defenderPlans = (az security pricing list --subscription $subscription.Id) | ConvertFrom-Json

        $defenderPlans | Where-Object { -not $_.deprecated } | ForEach-Object -Parallel {
            if ($_.pricingTier -ne "Free") {
                Write-Host "Resetting Microsoft Defender for Cloud Plan to Free for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))"
                az security pricing create --name $_.name --tier "Free" --subscription $subscription.Id
            } else {
                Write-Host "Microsoft Defender for Cloud Plan is already set to Free for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id)), skipping."
            }

    } -ThrottleLimit $throttleLimit

    Write-Host "Cleanup completed."
}