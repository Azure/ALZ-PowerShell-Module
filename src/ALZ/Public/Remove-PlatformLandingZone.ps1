function Remove-PlatformLandingZone {
    <#
    .SYNOPSIS
        Removes Azure Landing Zone platform resources including management groups and all resource groups within subscriptions.

    .DESCRIPTION
        The Remove-PlatformLandingZone function performs a comprehensive cleanup of Azure Landing Zone platform resources.
        It recursively deletes management groups, removes subscriptions from management groups, and deletes all resource
        groups within the affected subscriptions. This function is primarily designed for testing and cleanup scenarios.

        The function operates in the following sequence:
        1. Validates provided subscriptions (if any) exist in Azure
        2. Processes each specified management group, recursively discovering child management groups
        3. Removes subscriptions from management groups (starting from the deepest level)
        4. Discovers subscriptions from management groups (if not explicitly provided)
        5. Deletes management groups in reverse depth order (children before parents)
        6. Requests confirmation before deleting resource groups (unless bypassed)
        7. Deletes all resource groups in the discovered/specified subscriptions (excluding retention patterns)
        8. Resets Microsoft Defender for Cloud plans to Free tier

        CRITICAL WARNING: This is a highly destructive operation that will permanently delete Azure resources.
        By default, ALL resource groups in the subscriptions will be deleted unless they match retention patterns.
        Use with extreme caution and ensure you have appropriate backups and authorization before executing.

    .PARAMETER managementGroups
        An array of management group IDs or names to process. The function will delete these management groups and
        all their child management groups recursively. Subscriptions under these management groups will also be
        discovered (unless subscriptions are explicitly provided via the -subscriptions parameter).
        This parameter is mandatory.

    .PARAMETER subscriptions
        An optional array of subscription IDs or names to process for resource group deletion. If provided, the
        function will only delete resource groups from these specific subscriptions and will not discover additional
        subscriptions from management groups. If omitted, subscriptions will be discovered from the management groups
        being processed. Accepts both subscription IDs (GUIDs) and subscription names.
        Default: Empty array (discover from management groups)

    .PARAMETER resourceGroupsToRetainNamePatterns
        An array of regex patterns for resource group names that should be retained (not deleted). Resource groups
        matching any of these patterns will be skipped during the deletion process. This is useful for preserving
        critical infrastructure or billing-related resource groups.
        Default: @("VisualStudioOnline-") - Retains Azure DevOps billing resource groups

    .PARAMETER bypassConfirmation
        A switch parameter that bypasses the interactive confirmation prompts before deleting resource groups.
        When specified, the function will proceed with resource group deletion without asking for user confirmation.
        WARNING: Use this parameter with extreme caution as it eliminates safety checks.
        Default: $false (confirmation required)

    .PARAMETER throttleLimit
        The maximum number of parallel operations to execute simultaneously. This controls the degree of parallelism
        when processing management groups and resource groups. Higher values may improve performance but increase
        API throttling risk and resource consumption.
        Default: 11

    .EXAMPLE
        Remove-PlatformLandingZone -managementGroups @("alz-platform", "alz-landingzones")

        Removes the specified management groups and all their children, discovers subscriptions from those management
        groups, prompts for confirmation, then deletes all resource groups in the discovered subscriptions (except
        those matching retention patterns).

    .EXAMPLE
        Remove-PlatformLandingZone -managementGroups @("mg-dev") -subscriptions @("Sub-Dev-001", "Sub-Dev-002")

        Removes the "mg-dev" management group and deletes resource groups only from the two explicitly specified
        subscriptions. No additional subscriptions will be discovered from the management group.

    .EXAMPLE
        Remove-PlatformLandingZone -managementGroups @("alz-test") -bypassConfirmation

        Removes the management group and deletes all resource groups without prompting for confirmation.
        USE WITH EXTREME CAUTION!

    .EXAMPLE
        Remove-PlatformLandingZone -managementGroups @("alz-prod") -resourceGroupsToRetainNamePatterns @("VisualStudioOnline-", "RG-Critical-", "NetworkWatcherRG")

        Removes the management group but retains resource groups matching any of the specified patterns. This example
        preserves Azure DevOps billing resources, critical resource groups, and Network Watcher resource groups.

    .EXAMPLE
        $subs = @("12345678-1234-1234-1234-123456789012", "87654321-4321-4321-4321-210987654321")
        Remove-PlatformLandingZone -managementGroups @("alz-test") -subscriptions $subs -throttleLimit 5

        Removes the management group and processes only the specified subscriptions (by GUID) with reduced parallelism
        to minimize API throttling.

    .NOTES
        This function uses Azure CLI commands and requires:
        - Azure CLI to be installed and available in the system path
        - User to be authenticated to Azure (az login)
        - Appropriate RBAC permissions:
          * Management Group Contributor or Owner at the management group scope
          * Contributor or Owner at the subscription scope for resource group deletions
          * Security Admin for resetting Microsoft Defender for Cloud plans

        The function uses parallel processing with ForEach-Object -Parallel to improve performance when handling
        multiple management groups, subscriptions, and resource groups. The default throttle limit is 11.

        Resource group deletions include retry logic to handle dependencies between resources. If a resource group
        fails to delete (e.g., due to locks or dependencies), it will be retried after other resource groups in
        the same subscription have completed their deletion attempts.

        The function automatically resets Microsoft Defender for Cloud plans to the Free tier for all processed
        subscriptions. Plans that don't support the Free tier will be set to Standard tier instead.

        Subscription discovery behavior:
        - If -subscriptions is provided: Only those subscriptions are processed; no discovery occurs
        - If -subscriptions is empty: Subscriptions are discovered from management groups during cleanup

    .LINK
        https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/

    .LINK
        https://learn.microsoft.com/cli/azure/account/management-group

    .LINK
        https://learn.microsoft.com/azure/defender-for-cloud/
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string[]]$managementGroups,
        [string[]]$subscriptions = @(),
        [string[]]$resourceGroupsToRetainNamePatterns = @(
            "VisualStudioOnline-" # By default retain Visual Studio Online resource groups created for Azure DevOps billing purposes
        ),
        [switch]$bypassConfirmation,
        [int]$throttleLimit = 11,
        [switch]$planMode
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

    function Test-IsGuid {
        [OutputType([bool])]
        param (
            [Parameter(Mandatory = $true)]
            [string]$StringGuid
        )

        $ObjectGuid = [System.Guid]::empty
        return [System.Guid]::TryParse($StringGuid,[System.Management.Automation.PSReference]$ObjectGuid)
    }

    function Invoke-PromptForConfirmation {
        param (
            [string]$message,
            [string]$initialConfirmationText,
            [string]$finalConfirmationText = "YES I CONFIRM"
        )

        Write-Host "WARNING: $message" -ForegroundColor Red
        Write-Host "If you wish to proceed, type '$initialConfirmationText' to confirm." -ForegroundColor Red
        $confirmation = Read-Host "Enter the confirmation text"
        if ($confirmation -ne $initialConfirmationText) {
            Write-Host "Confirmation not received. Exiting without making any changes."
            return $false
        }
        Write-Host "WARNING: This operation is permanent cannot be reversed!" -ForegroundColor Red
        Write-Host "Are you sure you want to proceed? Type '$finalConfirmationText' to perform the highly destructive operation..." -ForegroundColor Red
        $confirmation = Read-Host "Enter the final confirmation text"
        if ($confirmation -ne $finalConfirmationText) {
            Write-Host "Final confirmation not received. Exiting without making any changes."
            return $false
        }
        Write-Host "Final confirmation received. Proceeding with destructive operation..." -ForegroundColor Green
        return $true
    }

    if ($PSCmdlet.ShouldProcess("Delete Management Groups and Clean Subscriptions", "delete")) {
        $funcDef = ${function:Get-ManagementGroupChildrenRecursive}.ToString()
        $subscriptionsProvided = $subscriptions.Count -gt 0
        if($subscriptionsProvided) {
            Write-Host "Subscriptions have been provided, checking they exist. We will not discover additional subscriptions from management groups..." -ForegroundColor Yellow
        } else {
            Write-Host "No subscriptions provided, discovering subscriptions from management groups..." -ForegroundColor Yellow
        }

        $subscriptionsFound = [System.Collections.Concurrent.ConcurrentBag[hashtable]]::new()

        foreach($subscription in $subscriptions) {
            $subscriptionObject = @{
                Id   = Test-IsGuid -StringGuid $subscription ? $subscription : (az account list --all --query "[?name=='$subscription'].id" -o tsv)
                Name = Test-IsGuid -StringGuid $subscription ? (az account list --all --query "[?id=='$subscription'].name" -o tsv) : $subscription
            }
            if(-not $subscriptionObject.Id -or -not $subscriptionObject.Name) {
                Write-Host "Subscription not found, skipping: $($subscription.Name) (ID: $($subscription.Id))" -ForegroundColor DarkBlue
                continue
            }
            $subscriptionsFound.Add($subscriptionObject)
        }

        if($managementGroups.Count -eq 0) {
            Write-Host "No management groups provided, skipping..." -ForegroundColor Yellow
        } else {
            if(-not $bypassConfirmation) {
                Write-Host ""
                Write-Host "The following Management Groups will be processed for removal:" -ForegroundColor DarkBlue
                $managementGroups | ForEach-Object { Write-Host "Management Group: $_" -ForegroundColor DarkBlue }
                Write-Host ""
                $continue = Invoke-PromptForConfirmation `
                    -message "ALL THE NAMED MANAGEMENT GROUPS AND THEIR CHILDREN WILL BE PERMANENTLY DELETED" `
                    -initialConfirmationText "I CONFIRM I UNDERSTAND ALL THE NAMED MANAGEMENT GROUPS AND THEIR CHILDREN WILL BE PERMANENTLY DELETED"
                if(-not $continue) {
                    Write-Host "Exiting..."
                    return
                }
            }
        }

        if($managementGroups.Count -ne 0) {
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

                $throttleLimit = $using:throttleLimit
                $planMode = $using:planMode

                foreach($depth in $reverseKeys) {
                    $managementGroups = $managementGroupsToDelete[$depth]

                    Write-Host "Deleting management groups at depth: $depth"

                    $managementGroups | ForEach-Object -Parallel {
                        $subscriptionsFound = $using:subscriptionsFound
                        $subscriptions = (az account management-group subscription show-sub-under-mg --name $_) | ConvertFrom-Json
                        if ($subscriptions.Count -gt 0) {
                            Write-Host "Management group has subscriptions: $_"
                            foreach ($subscription in $subscriptions) {
                                Write-Host "Removing subscription from management group: $_, subscription: $($subscription.displayName)"
                                if(-not $subscriptionsProvided) {
                                    $subscriptionsFound.Add(
                                        @{
                                            Id   = $subscription.name
                                            Name = $subscription.displayName
                                        }
                                    )
                                }
                                if($using:planMode) {
                                    Write-Host "(Plan Mode) Would run: az account management-group subscription remove --name $_ --subscription $($subscription.name)"
                                } else {
                                    az account management-group subscription remove --name $_ --subscription $subscription.name
                                }
                            }
                        } else {
                            Write-Host "Management group has no subscriptions: $_"
                        }

                        Write-Host "Deleting management group: $_"
                        if($using:planMode) {
                            Write-Host "(Plan Mode) Would run: az account management-group delete --name $_"
                        } else {
                            az account management-group delete --name $_
                        }
                    } -ThrottleLimit $using:throttleLimit
                }
            } -ThrottleLimit $throttleLimit
        }

        $subscriptionsFinal = $subscriptionsFound.ToArray() | Sort-Object -Property name -Unique

        if($subscriptionsFinal.Count -eq 0) {
            Write-Host "No subscriptions provided or found, skipping resource group deletion..." -ForegroundColor Yellow
            return
        } else {
            if(-not $bypassConfirmation) {
                Write-Host ""
                Write-Host "The following Subscriptions were provided or discovered during management group cleanup:" -ForegroundColor DarkBlue
                $subscriptionsFinal | ForEach-Object { Write-Host "Name: $($_.Name), ID: $($_.Id)" -ForegroundColor DarkBlue }
                Write-Host ""
                $continue = Invoke-PromptForConfirmation `
                    -message "ALL RESOURCE GROUPS IN THE NAMED SUBSCRIPTIONS WILL BE PERMANENTLY DELETED UNLESS THEY MATCH RETENTION PATTERNS" `
                    -initialConfirmationText "I CONFIRM I UNDERSTAND ALL SELECTED RESOURCE GROUPS IN THE NAMED SUBSCRIPTIONS WILL BE PERMANENTLY DELETED"
                if(-not $continue) {
                    Write-Host "Exiting..."
                    return
                }
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
                    Subscription      = $subscription
                }
            }

            $shouldRetry = $true

            $throttleLimit = $using:throttleLimit
            $planMode = $using:planMode

            while($shouldRetry) {
                $shouldRetry = $false
                $resourceGroupsToRetry = [System.Collections.Concurrent.ConcurrentBag[hashtable]]::new()
                $resourceGroupsToDelete | ForEach-Object -Parallel {
                    $resourceGroupName = $_.ResourceGroupName
                    $subscription = $_.Subscription

                    Write-Host "Deleting resource group for subscription: $($subscription.Name) (ID: $($subscription.Id)), resource group: $($ResourceGroupName)"
                    $result = $null
                    if($using:planMode) {
                        Write-Host "(Plan Mode) Would run: az group delete --name $ResourceGroupName --subscription $($subscription.Id) --yes"
                    } else {
                        $result = az group delete --name $ResourceGroupName --subscription $subscription.Id --yes 2>&1
                    }

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

            $defenderPlans.value | Where-Object { -not $_.deprecated } | ForEach-Object -Parallel {
                $subscription = $using:subscription
                if ($_.pricingTier -ne "Free") {
                    Write-Host "Resetting Microsoft Defender for Cloud Plan to Free for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))"
                    $result = $null
                    if($using:planMode) {
                        Write-Host "(Plan Mode) Would run: az security pricing create --name $($_.name) --tier `"Free`" --subscription $($subscription.Id)"
                    } else {
                        $result = (az security pricing create --name $_.name --tier "Free" --subscription $subscription.Id 2>&1)
                    }
                    if ($result -like "*must be 'Standard'*") {
                        Write-Host "Resetting Microsoft Defender for Cloud Plan to Standard as Free is not supported for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))"
                        if($using:planMode) {
                            Write-Host "(Plan Mode) Would run: az security pricing create --name $($_.name) --tier `"Standard`" --subscription $($subscription.Id)"
                        } else {
                            $result = az security pricing create --name $_.name --tier "Standard" --subscription $subscription.Id
                        }
                    }
                    Write-Host "Microsoft Defender for Cloud Plan reset for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))"
                } else {
                    Write-Host "Microsoft Defender for Cloud Plan is already set to Free for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id)), skipping."
                }
            } -ThrottleLimit $using:throttleLimit

        } -ThrottleLimit $throttleLimit

        Write-Host "Cleanup completed."
    }
}