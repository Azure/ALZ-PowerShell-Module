function Remove-PlatformLandingZone {
    <#
    .SYNOPSIS
        Removes Azure Landing Zone platform resources including management groups and all resource groups within subscriptions.

    .DESCRIPTION
        The Remove-PlatformLandingZone function performs a comprehensive cleanup of Azure Landing Zone platform resources.
        It can delete management group hierarchies, remove subscriptions from management groups, and delete all resource
        groups within the affected subscriptions. This function is primarily designed for testing and cleanup scenarios.

        The function operates in the following sequence:
        1. Validates provided management groups and subscriptions (if any) exist in Azure
        2. Prompts for confirmation (unless bypassed or in plan mode)
        3. Processes each specified management group, recursively discovering child management groups
        4. Removes subscriptions from management groups and optionally moves them to a target management group
        5. Discovers subscriptions from management groups (if not explicitly provided)
        6. Deletes management groups in reverse depth order (children before parents)
        7. Deletes management group-level deployments from target management groups (if not being deleted)
        8. Deletes orphaned role assignments from target management groups (if not being deleted)
        9. Deletes all resource groups in the discovered/specified subscriptions (excluding retention patterns)
        10. Resets Microsoft Defender for Cloud plans to Free tier
        11. Deletes all subscription-level deployments
        12. Deletes orphaned role assignments from subscriptions

        CRITICAL WARNING: This is a highly destructive operation that will permanently delete Azure resources.
        By default, ALL resource groups in the subscriptions will be deleted unless they match retention patterns.
        Use with extreme caution and ensure you have appropriate backups and authorization before executing.

    .PARAMETER ManagementGroups
        An array of management group IDs or names to process. By default, the function deletes child management groups
        one level below these target groups (not the target groups themselves). Use -DeleteTargetManagementGroups to
        delete the target groups as well. Subscriptions under these management groups will be discovered unless
        subscriptions are explicitly provided via the -Subscriptions parameter.

    .PARAMETER DeleteTargetManagementGroups
        A switch parameter that causes the target management groups specified in -ManagementGroups to be deleted along
        with all their children. By default, only management groups one level below the targets are deleted, preserving
        the target management groups themselves.
        Default: $false (preserve target management groups)

    .PARAMETER SubscriptionsTargetManagementGroup
        The management group ID or name where subscriptions should be moved after being removed from their current
        management groups. If not specified, subscriptions are removed from management groups without being reassigned.
        This is useful for maintaining subscription organization during cleanup operations.
        Default: $null (subscriptions are not reassigned)

    .PARAMETER Subscriptions
        An optional array of subscription IDs or names to process for resource group deletion. If provided, the
        function will only delete resource groups from these specific subscriptions and will not discover additional
        subscriptions from management groups. If omitted, subscriptions will be discovered from the management groups
        being processed. Accepts both subscription IDs (GUIDs) and subscription names.
        Default: Empty array (discover from management groups)

    .PARAMETER ResourceGroupsToRetainNamePatterns
        An array of regex patterns for resource group names that should be retained (not deleted). Resource groups
        matching any of these patterns will be skipped during the deletion process. This is useful for preserving
        critical infrastructure or billing-related resource groups.
        Default: @("VisualStudioOnline-") - Retains Azure DevOps billing resource groups

    .PARAMETER BypassConfirmation
        A switch parameter that bypasses the interactive confirmation prompts. When specified, the function waits
        for the duration specified in -BypassConfirmationTimeoutSeconds before proceeding, allowing time to cancel.
        During this timeout, pressing any key will cancel the operation.
        WARNING: Use this parameter with extreme caution as it reduces safety checks.
        Default: $false (confirmation required)

    .PARAMETER BypassConfirmationTimeoutSeconds
        The number of seconds to wait before proceeding when -BypassConfirmation is used. During this timeout,
        pressing any key will cancel the operation. This provides a safety window to prevent accidental deletions.
        Default: 30 seconds

    .PARAMETER ThrottleLimit
        The maximum number of parallel operations to execute simultaneously. This controls the degree of parallelism
        when processing management groups and resource groups. Higher values may improve performance but increase
        API throttling risk and resource consumption.
        Default: 11 "These go to eleven."

    .PARAMETER PlanMode
        A switch parameter that enables "dry run" mode. When specified, the function displays what actions would be
        taken without actually making any changes. This is useful for validating the scope of operations before
        executing the actual cleanup.
        Default: $false (execute actual deletions)

    .PARAMETER SkipDefenderPlanReset
        A switch parameter that skips the Microsoft Defender for Cloud plan reset operation. When specified, the
        function will not attempt to reset Defender plans to Free tier. This is useful when you want to preserve
        existing Defender configurations or when you don't have the necessary permissions.
        Default: $false (reset Defender plans)

    .PARAMETER SkipDeploymentDeletion
        A switch parameter that skips deployment deletion operations at both the management group and subscription
        levels. When specified, the function will not delete deployment history records from management groups or
        subscriptions. This is useful when you want to preserve deployment records for audit or compliance purposes.
        Default: $false (delete deployments)

    .PARAMETER SkipOrphanedRoleAssignmentDeletion
        A switch parameter that skips orphaned role assignment deletion operations at both the management group and
        subscription levels. When specified, the function will not delete role assignments where the principal no
        longer exists. This is useful when you want to preserve role assignment records or lack the necessary permissions.
        Default: $false (delete orphaned role assignments)

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-platform", "alz-landingzones")

        Removes all child management groups one level below "alz-platform" and "alz-landingzones", discovers
        subscriptions from those management groups, prompts for confirmation, then deletes all resource groups
        in the discovered subscriptions (except those matching retention patterns).

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -DeleteTargetManagementGroups

        Deletes the "alz-test" management group itself along with all its children, rather than just deleting
        one level below it.

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("mg-dev") -Subscriptions @("Sub-Dev-001", "Sub-Dev-002")

        Processes the "mg-dev" management group hierarchy and deletes resource groups only from the two explicitly
        specified subscriptions. No additional subscriptions will be discovered from the management group.

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -SubscriptionsTargetManagementGroup "mg-tenant-root"

        Removes child management groups and moves all discovered subscriptions to the "mg-tenant-root" management
        group instead of leaving them orphaned.

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-dev") -PlanMode

        Runs in plan mode (dry run) to show what would be deleted without making any actual changes. Useful for
        validating the scope before executing.

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -BypassConfirmation -BypassConfirmationTimeoutSeconds 60

        Bypasses interactive confirmation prompts but waits 60 seconds before proceeding, allowing time to cancel
        by pressing any key. USE WITH EXTREME CAUTION!

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-prod") -ResourceGroupsToRetainNamePatterns @("VisualStudioOnline-", "RG-Critical-", "NetworkWatcherRG")

        Removes management group hierarchy but retains resource groups matching any of the specified patterns.
        This example preserves Azure DevOps billing resources, critical resource groups, and Network Watcher resource groups.

    .EXAMPLE
        $subs = @("12345678-1234-1234-1234-123456789012", "87654321-4321-4321-4321-210987654321")
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -Subscriptions $subs -ThrottleLimit 5

        Processes the management group hierarchy and only the specified subscriptions (by GUID) with reduced
        parallelism to minimize API throttling.

    .EXAMPLE
        Remove-PlatformLandingZone -Subscriptions @("Sub-Test-001")

        Skips management group processing entirely and only deletes resource groups from the specified subscription.
        This is useful when you want to clean subscriptions without touching the management group structure.

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -SkipDefenderPlanReset -SkipDeploymentDeletion

        Removes management groups and resource groups but skips resetting Microsoft Defender plans and deleting
        deployment history. Useful for faster cleanup when Defender configuration and audit trails should be preserved.

    .EXAMPLE
        Remove-PlatformLandingZone -Subscriptions @("Sub-Test-001") -SkipOrphanedRoleAssignmentDeletion

        Cleans up the subscription but skips orphaned role assignment deletion. Useful when you want to preserve
        role assignments for review or lack the necessary permissions to delete them.

    .NOTES
        This function uses Azure CLI commands and requires:
        - Azure CLI to be installed and available in the system path
        - User to be authenticated to Azure (az login)
        - Appropriate RBAC permissions:
            * Management Group Contributor or Owner at the management group scope
            * Contributor or Owner at the subscription scope for resource group deletions
            * Security Admin for resetting Microsoft Defender for Cloud plans

        The function supports PowerShell's ShouldProcess pattern and respects -WhatIf and -Confirm parameters.

        The function uses parallel processing with ForEach-Object -Parallel to improve performance when handling
        multiple management groups, subscriptions, and resource groups. The default throttle limit is 11.

        Resource group deletions include retry logic to handle dependencies between resources. If a resource group
        fails to delete (e.g., due to locks or dependencies), it will be retried after other resource groups in
        the same subscription have completed their deletion attempts.

        The function automatically resets Microsoft Defender for Cloud plans to the Free tier for all processed
        subscriptions. Plans that don't support the Free tier will be set to Standard tier instead.

        Management group deletion behavior:
        - By default: Deletes management groups one level below the specified targets
        - With -deleteTargetManagementGroups: Deletes the target management groups and all their children

        Subscription discovery behavior:
        - If -subscriptions is provided: Only those subscriptions are processed; no discovery occurs
        - If -subscriptions is empty: Subscriptions are discovered from management groups during cleanup
        - If -subscriptionsTargetManagementGroup is specified: Subscriptions are moved to that management group

        Plan mode behavior:
        - All Azure CLI commands are displayed but not executed
        - Useful for validating scope and understanding impact before actual execution
        - Combine with -bypassConfirmation for fully automated dry runs

    .LINK
        https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/

    .LINK
        https://learn.microsoft.com/cli/azure/account/management-group

    .LINK
        https://learn.microsoft.com/azure/defender-for-cloud/
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string[]]$ManagementGroups,
        [switch]$DeleteTargetManagementGroups,
        [string]$SubscriptionsTargetManagementGroup = $null,
        [string[]]$Subscriptions = @(),
        [string[]]$ResourceGroupsToRetainNamePatterns = @(
            "VisualStudioOnline-" # By default retain Visual Studio Online resource groups created for Azure DevOps billing purposes
        ),
        [switch]$BypassConfirmation,
        [int]$BypassConfirmationTimeoutSeconds = 30,
        [int]$ThrottleLimit = 11,
        [switch]$PlanMode,
        [switch]$SkipDefenderPlanReset,
        [switch]$SkipDeploymentDeletion,
        [switch]$SkipOrphanedRoleAssignmentDeletion
    )

    function Write-ToConsoleLog {
        param (
            [string]$Message,
            [string]$Level = "INFO",
            [System.ConsoleColor]$Color = [System.ConsoleColor]::Blue,
            [switch]$NoNewLine,
            [switch]$Overwrite,
            [switch]$IsError,
            [switch]$IsWarning,
            [switch]$IsSuccess
        )

        $isDefaultColor = $Color -eq [System.ConsoleColor]::Blue

        if($IsError) {
            $Level = "ERROR"
        } elseif ($IsWarning) {
            $Level = "WARNING"
        } elseif ($IsSuccess) {
            $Level = "SUCCESS"
        }

        if($isDefaultColor) {
            if($Level -eq "ERROR") {
                $Color = [System.ConsoleColor]::Red
            } elseif ($Level -eq "WARNING") {
                $Color = [System.ConsoleColor]::Yellow
            } elseif ($Level -eq "SUCCESS") {
                $Color = [System.ConsoleColor]::Green
            }
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $prefix = ""

        if ($Overwrite) {
            $prefix = "`r"
        } else {
            if (-not $NoNewLine) {
                $prefix = [System.Environment]::NewLine
            }
        }
        Write-Host "$prefix[$timestamp] [$Level] $Message" -ForegroundColor $Color -NoNewline:$Overwrite.IsPresent
    }

    function Test-RequiredTooling {
        Write-ToConsoleLog "Checking the software requirements for the Accelerator..."

        $checkResults = @()
        $hasFailure = $false

        # Check if Azure CLI is installed
        Write-Verbose "Checking Azure CLI installation"
        $azCliPath = Get-Command az -ErrorAction SilentlyContinue
        if ($azCliPath) {
            $checkResults += @{
                message = "Azure CLI is installed."
                result  = "Success"
            }
        } else {
            $checkResults += @{
                message = "Azure CLI is not installed. Follow the instructions here: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
                result  = "Failure"
            }
            $hasFailure = $true
        }

        # Check if Azure CLI is logged in
        Write-Verbose "Checking Azure CLI login status"
        $azCliAccount = $(az account show -o json) | ConvertFrom-Json
        if ($azCliAccount) {
            $checkResults += @{
                message = "Azure CLI is logged in. Tenant ID: $($azCliAccount.tenantId), Subscription: $($azCliAccount.name) ($($azCliAccount.id))"
                result  = "Success"
            }
        } else {
            $checkResults += @{
                message = "Azure CLI is not logged in. Please login to Azure CLI using 'az login -t `"00000000-0000-0000-0000-000000000000}`"', replacing the empty GUID with your tenant ID."
                result  = "Failure"
            }
            $hasFailure = $true
        }

        Write-Verbose "Showing check results"
        Write-Verbose $(ConvertTo-Json $checkResults -Depth 100)
        $checkResults | ForEach-Object {[PSCustomObject]$_} | Format-Table -Property @{
            Label = "Check Result"; Expression = {
                switch ($_.result) {
                    'Success' { $color = "92"; break }
                    'Failure' { $color = "91"; break }
                    'Warning' { $color = "93"; break }
                    default { $color = "0" }
                }
                $e = [char]27
                "$e[${color}m$($_.result)${e}[0m"
            }
        }, @{ Label = "Check Details"; Expression = {$_.message} }  -AutoSize -Wrap

        if($hasFailure) {
            Write-ToConsoleLog "Software requirements have no been met, please review and install the missing software." -IsError
            Write-ToConsoleLog "Cannot continue with Deployment..." -IsError
            throw "Software requirements have no been met, please review and install the missing software."
        }

        Write-ToConsoleLog "All software requirements have been met." -IsSuccess
    }

    function Get-ManagementGroupChildrenRecursive {
        param (
            [object[]]$ManagementGroups,
            [int]$Depth = 0,
            [hashtable]$ManagementGroupsFound = @{}
        )

        $ManagementGroups = $ManagementGroups | Where-Object { $_.type -eq "Microsoft.Management/managementGroups" }

        foreach($managementGroup in $ManagementGroups) {
            if(!$ManagementGroupsFound.ContainsKey($Depth)) {
                $ManagementGroupsFound[$Depth] = @()
            }

            $ManagementGroupsFound[$Depth] += $managementGroup.name

            $children = $managementGroup.children | Where-Object { $_.type -eq "Microsoft.Management/managementGroups" }

            if ($children -and $children.Count -gt 0) {
                Write-ToConsoleLog "Management group has children: $($managementGroup.name)" -NoNewLine
                if(!$ManagementGroupsFound.ContainsKey($Depth + 1)) {
                    $ManagementGroupsFound[$Depth + 1] = @()
                }
                Get-ManagementGroupChildrenRecursive -ManagementGroups $children -Depth ($Depth + 1) -ManagementGroupsFound $ManagementGroupsFound
            } else {
                Write-ToConsoleLog "Management group has no children: $($managementGroup.name)" -NoNewLine
            }
        }

        if($Depth -eq 0) {
            return $ManagementGroupsFound
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
            [string]$Message,
            [string]$InitialConfirmationText,
            [string]$FinalConfirmationText = "YES I CONFIRM"
        )

        Write-ToConsoleLog "$Message" -IsWarning
        Write-ToConsoleLog "If you wish to proceed, type '$InitialConfirmationText' to confirm." -IsWarning
        $confirmation = Read-Host "Enter the confirmation text"
        if ($confirmation -ne $InitialConfirmationText) {
            Write-ToConsoleLog "Confirmation not received. Exiting without making any changes." -IsError
            return $false
        }
        Write-ToConsoleLog "Initial confirmation received." -IsSuccess
        Write-ToConsoleLog "WARNING: This operation is permanent cannot be reversed!" -IsWarning
        Write-ToConsoleLog "Are you sure you want to proceed? Type '$FinalConfirmationText' to perform the highly destructive operation..." -IsWarning
        $confirmation = Read-Host "Enter the final confirmation text"
        if ($confirmation -ne $FinalConfirmationText) {
            Write-ToConsoleLog "Final confirmation not received. Exiting without making any changes." -IsError
            return $false
        }
        Write-ToConsoleLog "Final confirmation received. Proceeding with destructive operation..." -IsSuccess
        return $true
    }

    function Remove-OrphanedRoleAssignmentsForScope {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [string]$ScopeType,
            [string]$ScopeNameForLogs,
            [string]$ScopeId,
            [int]$ThrottleLimit,
            [switch]$PlanMode
        )

        if(-not $PSCmdlet.ShouldProcess("Delete Orphaned Role Assignments", "delete")) {
            return
        }

        $funcWriteToConsoleLog = ${function:Write-ToConsoleLog}.ToString()
        $isSubscriptionScope = $ScopeType -eq "subscription"
        Write-ToConsoleLog "Checking for orphaned role assignments to delete in $($ScopeType): $ScopeNameForLogs" -NoNewLine
        $scopePrefix = $isSubscriptionScope ? "/subscriptions" : "/providers/Microsoft.Management/managementGroups"
        $roleAssignments = (az role assignment list --scope "$scopePrefix/$ScopeId" --query "[?principalName==''].{id:id,principalId:principalId,roleDefinitionName:roleDefinitionName}" -o json) | ConvertFrom-Json

        if ($roleAssignments -and $roleAssignments.Count -gt 0) {
            Write-ToConsoleLog "Found $($roleAssignments.Count) orphaned role assignment(s) in $($ScopeType): $ScopeNameForLogs" -NoNewLine

            $roleAssignments | ForEach-Object -Parallel {
                $roleAssignment = $_
                $ScopeType = $using:ScopeType
                $ScopeNameForLogs = $using:ScopeNameForLogs
                $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog

                Write-ToConsoleLog "Deleting orphaned role assignment: $($roleAssignment.roleDefinitionName) for principal: $($roleAssignment.principalId) from $($ScopeType): $ScopeNameForLogs" -NoNewLine
                $result = $null
                if($using:PlanMode) {
                    Write-ToConsoleLog "(Plan Mode) Would run: az role assignment delete --ids $($roleAssignment.id)" -NoNewLine -Color Gray
                } else {
                    $result = az role assignment delete --ids $roleAssignment.id 2>&1
                }

                if (!$result) {
                    Write-ToConsoleLog "Deleted orphaned role assignment: $($roleAssignment.roleDefinitionName) from $($ScopeType): $ScopeNameForLogs" -NoNewLine
                } else {
                    Write-ToConsoleLog "Failed to delete orphaned role assignment: $($roleAssignment.roleDefinitionName) from $($ScopeType): $ScopeNameForLogs" -IsWarning -NoNewLine
                }
            } -ThrottleLimit $using:ThrottleLimit

            Write-ToConsoleLog "All orphaned role assignments processed in $($ScopeType): $ScopeNameForLogs" -NoNewLine
        } else {
            Write-ToConsoleLog "No orphaned role assignments found in $($ScopeType): $ScopeNameForLogs, skipping." -NoNewLine
        }
    }

    function Remove-DeploymentsForScope {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [string]$ScopeType,
            [string]$ScopeNameForLogs,
            [string]$ScopeId,
            [int]$ThrottleLimit,
            [switch]$PlanMode
        )

        if(-not $PSCmdlet.ShouldProcess("Delete Deployments", "delete")) {
            return
        }

        $funcWriteToConsoleLog = ${function:Write-ToConsoleLog}.ToString()
        $isSubscriptionScope = $ScopeType -eq "subscription"

        Write-ToConsoleLog "Checking for deployments to delete in $($ScopeType): $ScopeNameForLogs" -NoNewLine

        $deployments = @()
        if ($isSubscriptionScope) {
            $deployments = (az deployment sub list --subscription $ScopeId --query "[].name" -o json) | ConvertFrom-Json
        } else {
            $deployments = (az deployment mg list --management-group-id $ScopeId --query "[].name" -o json) | ConvertFrom-Json
        }

        if ($deployments -and $deployments.Count -gt 0) {
            Write-ToConsoleLog "Found $($deployments.Count) deployment(s) in $($ScopeType): $scopeNameForLogs" -NoNewLine

            $deployments | ForEach-Object -Parallel {
                $deploymentName = $_
                $scopeId = $using:ScopeId
                $scopeNameForLogs = $using:ScopeNameForLogs
                $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog

                Write-ToConsoleLog "Deleting deployment: $deploymentName from $($scopeType): $scopeNameForLogs" -NoNewLine
                $result = $null
                if($isSubscriptionScope) {
                    if($using:PlanMode) {
                        Write-ToConsoleLog "(Plan Mode) Would run: az deployment sub delete --subscription $scopeId --name $deploymentName" -NoNewLine -Color Gray
                    } else {
                        $result = az deployment sub delete --subscription $scopeId --name $deploymentName 2>&1
                    }
                } else {
                    if($using:PlanMode) {
                        Write-ToConsoleLog "(Plan Mode) Would run: az deployment mg delete --management-group-id $scopeId --name $deploymentName" -NoNewLine -Color Gray
                    } else {
                        $result = az deployment mg delete --management-group-id $scopeId --name $deploymentName 2>&1
                    }
                }

                if (!$result) {
                    Write-ToConsoleLog "Deleted deployment: $deploymentName from $($scopeType): $scopeNameForLogs" -NoNewLine
                } else {
                    Write-ToConsoleLog "Failed to delete deployment: $deploymentName from $($scopeType): $scopeNameForLogs" -IsWarning -NoNewLine
                }
            } -ThrottleLimit $using:ThrottleLimit

            Write-ToConsoleLog "All deployments processed in $($scopeType): $scopeNameForLogs" -NoNewLine
        } else {
            Write-ToConsoleLog "No deployments found in $($scopeType): $scopeNameForLogs, skipping." -NoNewLine
        }
    }

    # Main execution starts here
    if ($PSCmdlet.ShouldProcess("Delete Management Groups and Clean Subscriptions", "delete")) {

        Test-RequiredTooling

        $funcWriteToConsoleLog = ${function:Write-ToConsoleLog}.ToString()
        $funcRemoveOrphanedRoleAssignmentsForScope = ${function:Remove-OrphanedRoleAssignmentsForScope}.ToString()
        $funcRemoveDeploymentsForScope = ${function:Remove-DeploymentsForScope}.ToString()

        if($BypassConfirmation) {
            Write-ToConsoleLog "Bypass confirmation enabled, proceeding without prompts..." -IsWarning
            Write-ToConsoleLog "This is a highly destructive operation that will permanently delete Azure resources!" -IsWarning
            Write-ToConsoleLog "We are waiting $BypassConfirmationTimeoutSeconds seconds to allow for cancellation. Press any key to cancel..." -IsWarning

            $keyPressed = $false
            $secondsRunning = 0

            while((-not $keyPressed) -and ($secondsRunning -lt $BypassConfirmationTimeoutSeconds)){
                $keyPressed = [Console]::KeyAvailable
                Write-ToConsoleLog ("Waiting for: $($BypassConfirmationTimeoutSeconds-$secondsRunning) seconds. Press any key to cancel...") -IsWarning -Overwrite
                Start-Sleep -Seconds 1
                $secondsRunning++
            }

            if($keyPressed) {
                Write-ToConsoleLog "Cancellation key pressed, exiting without making any changes..." -IsError
                return
            }
        }

        Write-ToConsoleLog "Thanks for providing the inputs, getting started..." -IsSuccess

        $managementGroupsProvided = $ManagementGroups.Count -gt 0
        $subscriptionsProvided = $Subscriptions.Count -gt 0

        if(-not $subscriptionsProvided -and -not $managementGroupsProvided) {
            Write-ToConsoleLog "No management groups or subscriptions provided, nothing to do. Exiting..." -IsError
            return
        }

        if(-not $managementGroupsProvided) {
            Write-ToConsoleLog "No management groups provided, skipping..." -IsWarning
        }

        $subscriptionsFound = [System.Collections.Concurrent.ConcurrentBag[hashtable]]::new()

        if($managementGroupsProvided) {
            $managementGroupsFound = @()

            if($SubscriptionsTargetManagementGroup) {
                Write-ToConsoleLog "Validating target management group for subscriptions: $SubscriptionsTargetManagementGroup"

                $managementGroupObject = (az account management-group show --name $SubscriptionsTargetManagementGroup) | ConvertFrom-Json
                if($null -eq $managementGroupObject) {
                    Write-ToConsoleLog "Target management group for subscriptions not found: $SubscriptionsTargetManagementGroup" -IsError
                    return
                }

                Write-ToConsoleLog "Subscriptions removed from management groups will be moved to target management group: $($managementGroupObject.name) ($($managementGroupObject.displayName))"
            }

            Write-ToConsoleLog "Validating provided management groups..."
            foreach($managementGroup in $ManagementGroups) {
                $managementGroupObject = (az account management-group show --name $managementGroup) | ConvertFrom-Json

                if($null -eq $managementGroupObject) {
                    Write-ToConsoleLog "Management group not found: $managementGroup" -IsWarning
                    continue
                }

                $managementGroupsFound += @{
                    Name        = $managementGroupObject.name
                    DisplayName = $managementGroupObject.displayName
                }
            }

            if($managementGroupsFound.Count -eq 0) {
                Write-ToConsoleLog "No valid management groups found from the provided list, exiting..." -IsError
                return
            }

            if(-not $BypassConfirmation) {
                Write-ToConsoleLog "The following Management Groups will be processed for removal:"
                $managementGroupsFound | ForEach-Object { Write-ToConsoleLog "Management Group: $($_.Name) ($($_.DisplayName))" -NoNewLine }
                $warningMessage = "ALL THE MANAGEMENT GROUP STRUCTURES ONE LEVEL BELOW THE LISTED MANAGEMENT GROUPS WILL BE PERMANENTLY DELETED"
                $confirmationText = "I CONFIRM I UNDERSTAND ALL THE MANAGEMENT GROUP STRUCTURES ONE LEVEL BELOW THE LISTED MANAGEMENT GROUPS WILL BE PERMANENTLY DELETED"
                if($DeleteTargetManagementGroups) {
                    $warningMessage = "ALL THE LISTED MANAGEMENTS GROUPS AND THEIR CHILDREN WILL BE PERMANENTLY DELETED"
                    $confirmationText = "I CONFIRM I UNDERSTAND ALL THE MANAGEMENT GROUPS AND THEIR CHILDREN WILL BE PERMANENTLY DELETED"
                }
                $continue = Invoke-PromptForConfirmation `
                    -message $warningMessage `
                    -initialConfirmationText $confirmationText
                if(-not $continue) {
                    Write-ToConsoleLog "Exiting..."
                    return
                }
            }

            $funcGetManagementGroupChildrenRecursive = ${function:Get-ManagementGroupChildrenRecursive}.ToString()

            if(-not $subscriptionsProvided) {
                Write-ToConsoleLog "No subscriptions provided, they will be discovered from the target management group hierarchy..."
            }

            if($managementGroupsFound.Count -ne 0) {
                $managementGroupsFound | ForEach-Object -Parallel {
                    $subscriptionsProvided = $using:subscriptionsProvided
                    $subscriptionsFound = $using:subscriptionsFound
                    $subscriptionsTargetManagementGroup = $using:SubscriptionsTargetManagementGroup
                    $deleteTargetManagementGroups = $using:DeleteTargetManagementGroups
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog

                    $managementGroupId = $_.Name
                    $managementGroupDisplayName = $_.DisplayName

                    Write-ToConsoleLog "Finding management group: $managementGroupId ($managementGroupDisplayName)" -NoNewLine
                    $topLevelManagementGroup = (az account management-group show --name $managementGroupId --expand --recurse) | ConvertFrom-Json

                    $hasChildren = $topLevelManagementGroup.children -and $topLevelManagementGroup.children.Count -gt 0

                    $managementGroupsToDelete = @{}

                    $targetManagementGroups = $deleteTargetManagementGroups ? @($topLevelManagementGroup) : @($topLevelManagementGroup.children)

                    if($hasChildren -or $deleteTargetManagementGroups) {
                        ${function:Get-ManagementGroupChildrenRecursive} = $using:funcGetManagementGroupChildrenRecursive
                        $managementGroupsToDelete = Get-ManagementGroupChildrenRecursive -ManagementGroups @($targetManagementGroups)
                    } else {
                        Write-ToConsoleLog "Management group has no children: $managementGroupId ($managementGroupDisplayName)" -NoNewLine
                    }

                    $reverseKeys = $managementGroupsToDelete.Keys | Sort-Object -Descending

                    $throttleLimit = $using:ThrottleLimit
                    $planMode = $using:PlanMode

                    foreach($depth in $reverseKeys) {
                        $managementGroups = $managementGroupsToDelete[$depth]

                        Write-ToConsoleLog "Deleting management groups at depth: $depth" -NoNewLine

                        $managementGroups | ForEach-Object -Parallel {
                            $subscriptionsFound = $using:subscriptionsFound
                            $subscriptionsTargetManagementGroup = $using:SubscriptionsTargetManagementGroup
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

                                    if($subscriptionsTargetManagementGroup) {
                                        Write-ToConsoleLog "Moving subscription to target management group: $($subscriptionsTargetManagementGroup), subscription: $($subscription.displayName)" -NoNewLine
                                        if($using:PlanMode) {
                                            Write-ToConsoleLog "(Plan Mode) Would run: az account management-group subscription add --name $($subscriptionsTargetManagementGroup) --subscription $($subscription.name)" -NoNewLine -Color Gray
                                        } else {
                                            az account management-group subscription add --name $subscriptionsTargetManagementGroup --subscription $subscription.name | Out-Null
                                        }
                                    } else {
                                        if($using:PlanMode) {
                                            Write-ToConsoleLog "(Plan Mode) Would run: az account management-group subscription remove --name $_ --subscription $($subscription.name)" -NoNewLine -Color Gray
                                        } else {
                                            az account management-group subscription remove --name $_ --subscription $subscription.name | Out-Null
                                        }
                                    }
                                }
                            } else {
                                Write-ToConsoleLog "Management group has no subscriptions: $_" -NoNewline
                            }

                            Write-ToConsoleLog "Deleting management group: $_" -NoNewline
                            if($using:PlanMode) {
                                Write-ToConsoleLog "(Plan Mode) Would run: az account management-group delete --name $_" -NoNewline -Color Gray
                            } else {
                                az account management-group delete --name $_ | Out-Null
                            }
                        } -ThrottleLimit $using:ThrottleLimit
                    }
                } -ThrottleLimit $ThrottleLimit
            }

            # Delete deployments from target management groups that are not being deleted
            if($managementGroupsFound.Count -ne 0 -and -not $SkipDeploymentDeletion) {
                $managementGroupsFound | ForEach-Object -Parallel {
                    $managementGroupId = $_.Name
                    $managementGroupDisplayName = $_.DisplayName
                    $deleteTargetManagementGroups = $using:DeleteTargetManagementGroups
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                    $funcRemoveDeploymentsForScope = $using:funcRemoveDeploymentsForScope
                    ${function:Remove-DeploymentsForScope} = $funcRemoveDeploymentsForScope

                    # Only delete deployments if this management group is not being deleted
                    if(-not $deleteTargetManagementGroups) {
                        Remove-DeploymentsForScope `
                            -ScopeType "management group" `
                            -ScopeNameForLogs "$managementGroupId ($managementGroupDisplayName)" `
                            -ScopeId $managementGroupId `
                            -ThrottleLimit $using:ThrottleLimit `
                            -PlanMode:$using:PlanMode
                    } else {
                        Write-ToConsoleLog "Skipping deployment deletion for management group: $managementGroupId ($managementGroupDisplayName) as it is being deleted" -NoNewLine
                    }
                } -ThrottleLimit $ThrottleLimit
            }

            # Delete orphaned role assignments from target management groups that are not being deleted
            if($managementGroupsFound.Count -ne 0 -and -not $SkipOrphanedRoleAssignmentDeletion) {
                $managementGroupsFound | ForEach-Object -Parallel {
                    $managementGroupId = $_.Name
                    $managementGroupDisplayName = $_.DisplayName
                    $deleteTargetManagementGroups = $using:DeleteTargetManagementGroups
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                    $funcRemoveOrphanedRoleAssignmentsForScope = $using:funcRemoveOrphanedRoleAssignmentsForScope
                    ${function:Remove-OrphanedRoleAssignmentsForScope} = $funcRemoveOrphanedRoleAssignmentsForScope

                    # Only delete role assignments if this management group is not being deleted
                    if(-not $deleteTargetManagementGroups) {
                        Remove-OrphanedRoleAssignmentsForScope `
                            -ScopeType "management group" `
                            -ScopeNameForLogs "$managementGroupId ($managementGroupDisplayName)" `
                            -ScopeId $managementGroupId `
                            -ThrottleLimit $using:ThrottleLimit `
                            -PlanMode:$using:PlanMode
                    } else {
                        Write-ToConsoleLog "Skipping orphaned role assignment deletion for management group: $managementGroupId ($managementGroupDisplayName) as it is being deleted" -NoNewLine
                    }
                } -ThrottleLimit $ThrottleLimit
            } elseif($managementGroupsFound.Count -ne 0) {
                Write-ToConsoleLog "Skipping orphaned role assignment deletion for all management groups as requested" -NoNewLine
            }
        }

        if($subscriptionsProvided) {
            Write-ToConsoleLog "Checking the provided subscriptions exist..."

            foreach($subscription in $Subscriptions) {
                $subscriptionObject = @{
                    Id   = (Test-IsGuid -StringGuid $subscription) ? $subscription : (az account list --all --query "[?name=='$subscription'].id" -o tsv)
                    Name = (Test-IsGuid -StringGuid $subscription) ? (az account list --all --query "[?id=='$subscription'].name" -o tsv) : $subscription
                }
                if(-not $subscriptionObject.Id -or -not $subscriptionObject.Name) {
                    Write-ToConsoleLog "Subscription not found, skipping: $($subscription.Name) (ID: $($subscription.Id))" -IsWarning
                    continue
                }
                $subscriptionsFound.Add($subscriptionObject)
            }
        }

        $subscriptionsFinal = $subscriptionsFound.ToArray() | Sort-Object -Property name -Unique

        if($subscriptionsFinal.Count -eq 0) {
            Write-ToConsoleLog "No subscriptions provided or found, skipping resource group deletion..." -IsWarning
            return
        } else {
            if(-not $BypassConfirmation) {
                Write-ToConsoleLog "The following Subscriptions were provided or discovered during management group cleanup:"
                $subscriptionsFinal | ForEach-Object { Write-ToConsoleLog "Name: $($_.Name), ID: $($_.Id)" -NoNewline }
                $continue = Invoke-PromptForConfirmation `
                    -Message "ALL RESOURCE GROUPS IN THE LISTED SUBSCRIPTIONS WILL BE PERMANENTLY DELETED UNLESS THEY MATCH RETENTION PATTERNS" `
                    -InitialConfirmationText "I CONFIRM I UNDERSTAND ALL SELECTED RESOURCE GROUPS IN THE NAMED SUBSCRIPTIONS WILL BE PERMANENTLY DELETED"
                if(-not $continue) {
                    Write-ToConsoleLog "Exiting..."
                    return
                }
            }
        }

        $subscriptionsFinal | ForEach-Object -Parallel {
            $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
            ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
            $funcRemoveOrphanedRoleAssignmentsForScope = $using:funcRemoveOrphanedRoleAssignmentsForScope
            ${function:Remove-OrphanedRoleAssignmentsForScope} = $funcRemoveOrphanedRoleAssignmentsForScope
            $funcRemoveDeploymentsForScope = $using:funcRemoveDeploymentsForScope
            ${function:Remove-DeploymentsForScope} = $funcRemoveDeploymentsForScope

            $subscription = $_
            Write-ToConsoleLog "Finding resource groups for subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewline

            $resourceGroups = (az group list --subscription $subscription.Id) | ConvertFrom-Json

            if ($resourceGroups.Count -eq 0) {
                Write-ToConsoleLog "No resource groups found for subscription: $($subscription.Name) (ID: $($subscription.Id)), skipping." -NoNewline
                continue
            }

            Write-ToConsoleLog "Found resource groups for subscription: $($subscription.Name) (ID: $($subscription.Id)), count: $($resourceGroups.Count)" -NoNewline

            $resourceGroupsToDelete = @()
            $resourceGroupsToRetainNamePatterns = $using:ResourceGroupsToRetainNamePatterns

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

            $throttleLimit = $using:ThrottleLimit
            $planMode = $using:PlanMode

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
                    if($using:PlanMode) {
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
                } -ThrottleLimit $using:ThrottleLimit

                if($resourceGroupsToRetry.Count -gt 0) {
                    Write-ToConsoleLog "Some resource groups failed to delete and will be retried in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                    $shouldRetry = $true
                    $resourceGroupsToDelete = $resourceGroupsToRetry.ToArray()
                } else {
                    Write-ToConsoleLog "All resource groups deleted successfully in subscription: $($subscription.Name) (ID: $($subscription.Id))." -NoNewLine
                }
            }

            if(-not $using:SkipDefenderPlanReset) {
                Write-ToConsoleLog "Checking for Microsoft Defender for Cloud Plans to reset in subscription: $($subscription.Name) (ID: $($subscription.Id))"
                $defenderPlans = (az security pricing list --subscription $subscription.Id) | ConvertFrom-Json

                $defenderPlans.value | Where-Object { -not $_.deprecated } | ForEach-Object -Parallel {
                    $subscription = $using:subscription
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog

                    if ($_.pricingTier -ne "Free") {
                        Write-ToConsoleLog "Resetting Microsoft Defender for Cloud Plan to Free for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                        $result = $null
                        if($using:PlanMode) {
                            Write-ToConsoleLog "(Plan Mode) Would run: az security pricing create --name $($_.name) --tier `"Free`" --subscription $($subscription.Id)" -NoNewLine -Color Gray
                        } else {
                            $result = (az security pricing create --name $_.name --tier "Free" --subscription $subscription.Id 2>&1)
                        }
                        if ($result -like "*must be 'Standard'*") {
                            Write-ToConsoleLog "Resetting Microsoft Defender for Cloud Plan to Standard as Free is not supported for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                            if($using:PlanMode) {
                                Write-ToConsoleLog "(Plan Mode) Would run: az security pricing create --name $($_.name) --tier `"Standard`" --subscription $($subscription.Id)" -NoNewLine -Color Gray
                            } else {
                                $result = az security pricing create --name $_.name --tier "Standard" --subscription $subscription.Id
                            }
                        }
                        Write-ToConsoleLog "Microsoft Defender for Cloud Plan reset for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                    } else {
                        Write-ToConsoleLog "Microsoft Defender for Cloud Plan is already set to Free for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id)), skipping." -NoNewLine
                    }
                } -ThrottleLimit $using:ThrottleLimit
            } else {
                Write-ToConsoleLog "Skipping Microsoft Defender for Cloud Plans reset in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
            }

            if(-not $using:SkipDeploymentDeletion) {
                Remove-DeploymentsForScope `
                    -ScopeType "subscription" `
                    -ScopeNameForLogs "$($subscription.Name) (ID: $($subscription.Id))" `
                    -ScopeId $subscription.Id `
                    -ThrottleLimit $using:ThrottleLimit `
                    -PlanMode:$using:PlanMode
            } else {
                Write-ToConsoleLog "Skipping subscription level deployment deletion in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
            }

            if(-not $using:SkipOrphanedRoleAssignmentDeletion) {
                Remove-OrphanedRoleAssignmentsForScope `
                    -ScopeType "subscription" `
                    -ScopeNameForLogs "$($subscription.Name) (ID: $($subscription.Id))" `
                    -ScopeId $subscription.Id `
                    -ThrottleLimit $using:ThrottleLimit `
                    -PlanMode:$using:PlanMode
            } else {
                Write-ToConsoleLog "Skipping orphaned role assignment deletion in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
            }

        } -ThrottleLimit $ThrottleLimit

        Write-ToConsoleLog "Cleanup completed." -IsSuccess
    }
}
