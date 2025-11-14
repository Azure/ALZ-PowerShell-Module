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
        [string]$subscriptionTargetManagementGroup = $null,
        [string[]]$subscriptions = @(),
        [string[]]$resourceGroupsToRetainNamePatterns = @(
            "VisualStudioOnline-" # By default retain Visual Studio Online resource groups created for Azure DevOps billing purposes
        ),
        [switch]$bypassConfirmation,
        [int]$throttleLimit = 11,
        [switch]$planMode
    )

    function Write-ToConsoleLog {
        param (
            [string]$Message,
            [string]$Level = "INFO",
            [System.ConsoleColor]$Color = [System.ConsoleColor]::Yellow,
            [switch]$NoNewLine
        )

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $prefix = ""
        if (-not $NoNewLine) {
            $Prefix = [System.Environment]::NewLine
        }
        Write-Host "$Prefix[$timestamp] [$Level] $Message" -ForegroundColor $Color
    }

    function Get-ManagementGroupChildrenRecursive {
        param (
            [object[]]$managementGroups,
            [int]$depth = 0,
            [hashtable]$managementGroupsFound = @{}
        )

        $managementGroups = $managementGroups | Where-Object { $_.type -eq "Microsoft.Management/managementGroups" }

        foreach($managementGroup in $managementGroups) {
            if(!$managementGroupsFound.ContainsKey($depth)) {
                $managementGroupsFound[$depth] = @()
            }

            $managementGroupsFound[$depth] += $managementGroup.name

            $children = $managementGroup.children | Where-Object { $_.type -eq "Microsoft.Management/managementGroups" }

            if ($children -and $children.Count -gt 0) {
                Write-ToConsoleLog "Management group has children: $($managementGroup.name)" -NoNewLine
                if(!$managementGroupsFound.ContainsKey($depth + 1)) {
                    $managementGroupsFound[$depth + 1] = @()
                }
                Get-ManagementGroupChildrenRecursive -managementGroups $children -depth ($depth + 1) -managementGroupsFound $managementGroupsFound
            } else {
                Write-ToConsoleLog "Management group has no children: $($managementGroup.name)" -NoNewLine
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

        Write-ToConsoleLog "$message" -Color DarkMagenta -Level "WARNING"
        Write-ToConsoleLog "If you wish to proceed, type '$initialConfirmationText' to confirm." -Color DarkMagenta -Level "WARNING"
        $confirmation = Read-Host "Enter the confirmation text"
        if ($confirmation -ne $initialConfirmationText) {
            Write-ToConsoleLog "Confirmation not received. Exiting without making any changes." -Color Red -Level "ERROR"
            return $false
        }
        Write-ToConsoleLog "Initial confirmation received."
        Write-ToConsoleLog "WARNING: This operation is permanent cannot be reversed!" -Color Magenta -Level "WARNING"
        Write-ToConsoleLog "Are you sure you want to proceed? Type '$finalConfirmationText' to perform the highly destructive operation..." -Color Magenta  -Level "WARNING"
        $confirmation = Read-Host "Enter the final confirmation text"
        if ($confirmation -ne $finalConfirmationText) {
            Write-ToConsoleLog "Final confirmation not received. Exiting without making any changes." -Color Red -Level "ERROR"
            return $false
        }
        Write-ToConsoleLog "Final confirmation received. Proceeding with destructive operation..."
        return $true
    }



    if ($PSCmdlet.ShouldProcess("Delete Management Groups and Clean Subscriptions", "delete")) {

        $managementGroupsProvided = $managementGroups.Count -gt 0
        $subscriptionsProvided = $subscriptions.Count -gt 0

        if(-not $subscriptionsProvided -and -not $managementGroupsProvided) {
            Write-ToConsoleLog "No management groups or subscriptions provided, nothing to do. Exiting..." -Color Green
            return
        }

        if(-not $managementGroupsProvided) {
            Write-ToConsoleLog "No management groups provided, skipping..."
        }

        $subscriptionsFound = [System.Collections.Concurrent.ConcurrentBag[hashtable]]::new()

        if($managementGroupsProvided) {
            $managementGroupsFound = @()
            foreach($managementGroup in $managementGroups) {
                $managementGroup = (az account management-group show --name $managementGroup) | ConvertFrom-Json

                if($null -eq $managementGroup) {
                    Write-ToConsoleLog "Management group not found: $managementGroup" -Color DarkYellow -Level "WARNING"
                    continue
                }

                $managementGroupsFound += @{
                    Name        = $managementGroup.name
                    DisplayName = $managementGroup.displayName
                }
            }

            if(-not $bypassConfirmation) {
                Write-ToConsoleLog "The following Management Groups will be processed for removal:" -Color DarkBlue
                $managementGroupsFound | ForEach-Object { Write-ToConsoleLog "Management Group: $($_.Name) ($($_.DisplayName))" -Color Blue -NoNewLine }
                $continue = Invoke-PromptForConfirmation `
                    -message "ALL THE CHILD MANAGEMENT GROUPS OF THE LISTED MANAGEMENTS GROUPS AND THEIR CHILDREN WILL BE PERMANENTLY DELETED" `
                    -initialConfirmationText "I CONFIRM I UNDERSTAND ALL THE CHILD MANAGEMENT GROUPS AND THEIR CHILDREN WILL BE PERMANENTLY DELETED"
                if(-not $continue) {
                    Write-ToConsoleLog "Exiting..."
                    return
                }
            }

            $funcGetManagementGroupChildrenRecursive = ${function:Get-ManagementGroupChildrenRecursive}.ToString()
            $funcWriteToConsoleLog = ${function:Write-ToConsoleLog}.ToString()

            if(-not $subscriptionsProvided) {
                Write-ToConsoleLog "No subscriptions provided, they will be discovered from the target management group hierarchy..." -Color Yellow
            }

            if($managementGroupsFound.Count -ne 0) {
                $managementGroupsFound | ForEach-Object -Parallel {
                    $subscriptionsProvided = $using:subscriptionsProvided
                    $subscriptionsFound = $using:subscriptionsFound
                    $subscriptionTargetManagementGroup = $using:subscriptionTargetManagementGroup
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog

                    $managementGroupId = $_.Name
                    $managementGroupDisplayName = $_.DisplayName

                    Write-ToConsoleLog "Finding management group: $managementGroupId ($managementGroupDisplayName)" -NoNewLine
                    $topLevelManagementGroup = (az account management-group show --name $managementGroupId --expand --recurse) | ConvertFrom-Json

                    $hasChildren = $topLevelManagementGroup.children -and $topLevelManagementGroup.children.Count -gt 0

                    $managementGroupsToDelete = @{}

                    if($hasChildren) {
                        ${function:Get-ManagementGroupChildrenRecursive} = $using:funcGetManagementGroupChildrenRecursive
                        $managementGroupsToDelete = Get-ManagementGroupChildrenRecursive -managementGroups @($topLevelManagementGroup.children)
                    } else {
                        Write-ToConsoleLog "Management group has no children: $managementGroupId ($managementGroupDisplayName)" -NoNewLine
                    }

                    $reverseKeys = $managementGroupsToDelete.Keys | Sort-Object -Descending

                    $throttleLimit = $using:throttleLimit
                    $planMode = $using:planMode

                    foreach($depth in $reverseKeys) {
                        $managementGroups = $managementGroupsToDelete[$depth]

                        Write-ToConsoleLog "Deleting management groups at depth: $depth" -NoNewLine

                        $managementGroups | ForEach-Object -Parallel {
                            $subscriptionsFound = $using:subscriptionsFound
                            $subscriptionTargetManagementGroup = $using:subscriptionTargetManagementGroup
                            $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                            ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog

                            $subscriptions = (az account management-group subscription show-sub-under-mg --name $_) | ConvertFrom-Json
                            if ($subscriptions.Count -gt 0) {
                                Write-ToConsoleLog "Management group has subscriptions: $_" -NoNewLine
                                foreach ($subscription in $subscriptions) {
                                    Write-ToConsoleLog "Removing subscription from management group: $_, subscription: $($subscription.displayName)" -NoNewLine
                                    if(-not $subscriptionsProvided) {
                                        $subscriptionsFound.Add(
                                            @{
                                                Id   = $subscription.name
                                                Name = $subscription.displayName
                                            }
                                        )
                                    }

                                    if($subscriptionTargetManagementGroup) {
                                        Write-ToConsoleLog "Moving subscription to target management group: $($subscriptionTargetManagementGroup), subscription: $($subscription.displayName)" -NoNewLine
                                        if($using:planMode) {
                                            Write-ToConsoleLog "(Plan Mode) Would run: az account management-group subscription add --name $($subscriptionTargetManagementGroup) --subscription $($subscription.name)" -NoNewLine -Color Gray
                                        } else {
                                            az account management-group subscription add --name $subscriptionTargetManagementGroup --subscription $subscription.name
                                        }
                                    } else {
                                        if($using:planMode) {
                                            Write-ToConsoleLog "(Plan Mode) Would run: az account management-group subscription remove --name $_ --subscription $($subscription.name)" -NoNewLine -Color Gray
                                        } else {
                                            az account management-group subscription remove --name $_ --subscription $subscription.name
                                        }
                                    }
                                }
                            } else {
                                Write-ToConsoleLog "Management group has no subscriptions: $_" -NoNewline
                            }

                            Write-ToConsoleLog "Deleting management group: $_" -NoNewline
                            if($using:planMode) {
                                Write-ToConsoleLog "(Plan Mode) Would run: az account management-group delete --name $_" -NoNewline -Color Gray
                            } else {
                                az account management-group delete --name $_
                            }
                        } -ThrottleLimit $using:throttleLimit
                    }
                } -ThrottleLimit $throttleLimit
            }
        }

        if($subscriptionsProvided) {
            Write-ToConsoleLog "Checking the provided subscriptions exist..."
        }

        foreach($subscription in $subscriptions) {
            $subscriptionObject = @{
                Id   = Test-IsGuid -StringGuid $subscription ? $subscription : (az account list --all --query "[?name=='$subscription'].id" -o tsv)
                Name = Test-IsGuid -StringGuid $subscription ? (az account list --all --query "[?id=='$subscription'].name" -o tsv) : $subscription
            }
            if(-not $subscriptionObject.Id -or -not $subscriptionObject.Name) {
                Write-ToConsoleLog "Subscription not found, skipping: $($subscription.Name) (ID: $($subscription.Id))" -Color DarkYellow -Level "WARNING"
                continue
            }
            $subscriptionsFound.Add($subscriptionObject)
        }

        $subscriptionsFinal = $subscriptionsFound.ToArray() | Sort-Object -Property name -Unique

        if($subscriptionsFinal.Count -eq 0) {
            Write-ToConsoleLog "No subscriptions provided or found, skipping resource group deletion..."
            return
        } else {
            if(-not $bypassConfirmation) {
                Write-ToConsoleLog "The following Subscriptions were provided or discovered during management group cleanup:" -Color DarkBlue
                $subscriptionsFinal | ForEach-Object { Write-ToConsoleLog "Name: $($_.Name), ID: $($_.Id)" -Color DarkBlue -NoNewline }
                $continue = Invoke-PromptForConfirmation `
                    -message "ALL RESOURCE GROUPS IN THE LISTED SUBSCRIPTIONS WILL BE PERMANENTLY DELETED UNLESS THEY MATCH RETENTION PATTERNS" `
                    -initialConfirmationText "I CONFIRM I UNDERSTAND ALL SELECTED RESOURCE GROUPS IN THE NAMED SUBSCRIPTIONS WILL BE PERMANENTLY DELETED"
                if(-not $continue) {
                    Write-ToConsoleLog "Exiting..."
                    return
                }
            }
        }

        $subscriptionsFinal | ForEach-Object -Parallel {
            $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
            ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog

            $subscription = $_
            Write-ToConsoleLog "Finding resource groups for subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewline

            $resourceGroups = (az group list --subscription $subscription.Id) | ConvertFrom-Json

            if ($resourceGroups.Count -eq 0) {
                Write-ToConsoleLog "No resource groups found for subscription: $($subscription.Name) (ID: $($subscription.Id)), skipping." -NoNewline
                continue
            }

            Write-ToConsoleLog "Found resource groups for subscription: $($subscription.Name) (ID: $($subscription.Id)), count: $($resourceGroups.Count)" -NoNewline

            $resourceGroupsToDelete = @()
            $resourceGroupsToRetainNamePatterns = $using:resourceGroupsToRetainNamePatterns

            foreach ($resourceGroup in $resourceGroups) {
                $foundMatch = $false

                foreach ($pattern in $resourceGroupsToRetainNamePatterns) {
                    if ($resourceGroup.name -match $pattern) {
                        Write-ToConsoleLog "Retaining resource group as it matches the pattern '$pattern': $($resourceGroup.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
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
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                    $resourceGroupName = $_.ResourceGroupName
                    $subscription = $_.Subscription

                    Write-ToConsoleLog "Deleting resource group for subscription: $($subscription.Name) (ID: $($subscription.Id)), resource group: $($ResourceGroupName)" -NoNewLine
                    $result = $null
                    if($using:planMode) {
                        Write-ToConsoleLog "(Plan Mode) Would run: az group delete --name $ResourceGroupName --subscription $($subscription.Id) --yes" -NoNewLine -Color Gray
                    } else {
                        $result = az group delete --name $ResourceGroupName --subscription $subscription.Id --yes 2>&1
                    }

                    if (!$result) {
                        Write-ToConsoleLog "Deleted resource group for subscription: $($subscription.Name) (ID: $($subscription.Id)), resource group: $($ResourceGroupName)" -NoNewLine
                    } else {
                        Write-ToConsoleLog "Delete resource group failed for subscription: $($subscription.Name) (ID: $($subscription.Id)), resource group: $($ResourceGroupName)" -NoNewLine
                        Write-ToConsoleLog "It will be retried once the other resource groups in the subscription have reported their status." -NoNewLine
                        $retries = $using:resourceGroupsToRetry
                        $retries.Add($_)
                    }
                } -ThrottleLimit $using:throttleLimit

                if($resourceGroupsToRetry.Count -gt 0) {
                    Write-ToConsoleLog "Some resource groups failed to delete and will be retried in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                    $shouldRetry = $true
                    $resourceGroupsToDelete = $resourceGroupsToRetry.ToArray()
                } else {
                    Write-ToConsoleLog "All resource groups deleted successfully in subscription: $($subscription.Name) (ID: $($subscription.Id))." -NoNewLine
                }
            }

            Write-ToConsoleLog "Checking for Microsoft Defender for Cloud Plans to reset in subscription: $($subscription.Name) (ID: $($subscription.Id))"
            $defenderPlans = (az security pricing list --subscription $subscription.Id) | ConvertFrom-Json

            $defenderPlans.value | Where-Object { -not $_.deprecated } | ForEach-Object -Parallel {
                $subscription = $using:subscription
                $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog

                if ($_.pricingTier -ne "Free") {
                    Write-ToConsoleLog "Resetting Microsoft Defender for Cloud Plan to Free for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                    $result = $null
                    if($using:planMode) {
                        Write-ToConsoleLog "(Plan Mode) Would run: az security pricing create --name $($_.name) --tier `"Free`" --subscription $($subscription.Id)" -NoNewLine -Color Gray
                    } else {
                        $result = (az security pricing create --name $_.name --tier "Free" --subscription $subscription.Id 2>&1)
                    }
                    if ($result -like "*must be 'Standard'*") {
                        Write-ToConsoleLog "Resetting Microsoft Defender for Cloud Plan to Standard as Free is not supported for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                        if($using:planMode) {
                            Write-ToConsoleLog "(Plan Mode) Would run: az security pricing create --name $($_.name) --tier `"Standard`" --subscription $($subscription.Id)" -NoNewLine -Color Gray
                        } else {
                            $result = az security pricing create --name $_.name --tier "Standard" --subscription $subscription.Id
                        }
                    }
                    Write-ToConsoleLog "Microsoft Defender for Cloud Plan reset for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                } else {
                    Write-ToConsoleLog "Microsoft Defender for Cloud Plan is already set to Free for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id)), skipping."-NoNewLine
                }
            } -ThrottleLimit $using:throttleLimit

        } -ThrottleLimit $throttleLimit

        Write-ToConsoleLog "Cleanup completed." -Color Green
    }
}