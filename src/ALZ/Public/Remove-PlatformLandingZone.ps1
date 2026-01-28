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
        9. Deletes custom role assignments and definitions from target management groups (if not being deleted)
        10. Deletes all resource groups in the discovered/specified subscriptions (excluding retention patterns)
        11. Resets Microsoft Defender for Cloud plans to Free tier
        12. Deletes all subscription-level deployments
        13. Deletes orphaned role assignments from subscriptions

        CRITICAL WARNING: This is a highly destructive operation that will permanently delete Azure resources.
        By default, ALL resource groups in the subscriptions will be deleted unless they match retention patterns.
        Use with extreme caution and ensure you have appropriate backups and authorization before executing.

    .PARAMETER ManagementGroups
        An array of regex patterns to match against management group names or display names. The function queries
        all management groups in the tenant and matches each pattern against both the name and displayName properties.
        Multiple management groups can match a single pattern. By default, the function deletes child management groups
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

    .PARAMETER AdditionalSubscriptions
        An optional array of additional subscription IDs or names to include in the cleanup process. These subscriptions
        will be merged with the subscriptions that are either discovered from management groups or explicitly provided
        via the -Subscriptions parameter. This is useful for cleaning up bootstrap subscriptions or other subscriptions
        that may sit outside the management group hierarchy being processed. Accepts both subscription IDs (GUIDs)
        and subscription names.
        Default: Empty array (no additional subscriptions)

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

    .PARAMETER SkipDeploymentStackDeletion
        A switch parameter that skips deployment stack deletion operations at both the management group and subscription
        levels. When specified, the function will not delete deployment stacks from management groups or subscriptions.
        This is useful when you want to preserve deployment stacks or lack the necessary permissions to delete them.
        Default: $false (delete deployment stacks)

    .PARAMETER SkipOrphanedRoleAssignmentDeletion
        A switch parameter that skips orphaned role assignment deletion operations at both the management group and
        subscription levels. When specified, the function will not delete role assignments where the principal no
        longer exists. This is useful when you want to preserve role assignment records or lack the necessary permissions.
        Default: $false (delete orphaned role assignments)

    .PARAMETER SkipCustomRoleDefinitionDeletion
        A switch parameter that skips custom role definition deletion operations on target management groups that are
        not being deleted. When specified, the function will not delete custom role definitions or their assignments.
        This is useful when you want to preserve custom role definitions or lack the necessary permissions to delete them.
        Default: $false (delete custom role definitions)

    .PARAMETER ManagementGroupsToDeleteNamePatterns
        An array of wildcard patterns for management group names that should be deleted. Only management groups at the
        first level below the target management groups matching any of these patterns will be deleted. If the array is
        empty, all child management groups will be deleted (default behavior). Each pattern is evaluated using a -like
        expression with wildcards at the start and end (e.g., a pattern of "landingzone" will match management groups
        containing "landingzone" anywhere in their name).
        Default: Empty array (delete all child management groups)

    .PARAMETER RoleDefinitionsToDeleteNamePatterns
        An array of wildcard patterns for custom role definition names that should be deleted. Only role definitions
        matching any of these patterns will be deleted during the custom role definition cleanup process. If the array
        is empty, all custom role definitions will be deleted (default behavior). Each pattern is evaluated using a
        -like expression with wildcards at the start and end (e.g., a pattern of "Custom" will match role definitions
        containing "Custom" anywhere in their name).
        Default: Empty array (delete all custom role definitions)

    .PARAMETER DeploymentStacksToDeleteNamePatterns
        An array of wildcard patterns for deployment stack names that should be deleted. Only deployment stacks
        matching any of these patterns will be deleted during the deployment stack cleanup process. If the array
        is empty, all deployment stacks will be deleted (default behavior). Each pattern is evaluated using a
        -like expression with wildcards at the start and end (e.g., a pattern of "alz" will match deployment stacks
        containing "alz" anywhere in their name).
        Default: Empty array (delete all deployment stacks)

    .PARAMETER AllowNoManagementGroupMatch
        A switch parameter that allows the function to continue processing subscriptions even when no valid
        management groups are found from the provided list. When specified, a warning is logged instead of an
        error, and the function continues to subscription cleanup. This is useful when the management groups
        may have already been deleted but you still want to clean up subscriptions.
        Default: $false (exit with error if no management groups found)

    .PARAMETER ForceSubscriptionPlacement
        A switch parameter that forces moving all subscriptions (provided via -Subscriptions or -AdditionalSubscriptions)
        to the management group specified in -SubscriptionsTargetManagementGroup. If -SubscriptionsTargetManagementGroup
        is not specified, the default management group is determined from the tenant's hierarchy settings
        (via az account management-group hierarchy-settings list), falling back to tenant root if no default is configured.
        Before moving, the function checks if each subscription is already under the target management group and skips
        the move if it is.
        Default: $false (do not force placement)

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -AdditionalSubscriptions @("Bootstrap-Sub-001")

        Processes the "alz-test" management group hierarchy, discovers subscriptions from the management groups,
        and also includes the "Bootstrap-Sub-001" subscription in the cleanup process. This is useful when the
        bootstrap subscription sits outside the management group hierarchy being processed.

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -Subscriptions @("Sub-Test-001") -AdditionalSubscriptions @("12345678-1234-1234-1234-123456789012")

        Processes the "alz-test" management group hierarchy and cleans up both the explicitly provided subscription
        "Sub-Test-001" and the additional subscription specified by GUID. The additional subscriptions are merged
        with the provided subscriptions for resource group deletion.

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
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -SkipDeploymentStackDeletion

        Removes management groups and resource groups but skips deleting deployment stacks. Useful when you want to
        preserve deployment stacks for managed resource cleanup or lack the necessary permissions to delete them.

    .EXAMPLE
        Remove-PlatformLandingZone -Subscriptions @("Sub-Test-001") -SkipOrphanedRoleAssignmentDeletion

        Cleans up the subscription but skips orphaned role assignment deletion. Useful when you want to preserve
        role assignments for review or lack the necessary permissions to delete them.

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -SkipCustomRoleDefinitionDeletion

        Removes management groups and resource groups but skips custom role definition deletion. Useful when you want
        to preserve custom role definitions or lack the necessary permissions to delete them.

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-root") -ManagementGroupsToDeleteNamePatterns @("landingzone", "sandbox")

        Removes only child management groups with names containing "landingzone" or "sandbox", preserving all other
        child management groups. This is useful when you want to selectively clean up specific management group branches.

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -RoleDefinitionsToDeleteNamePatterns @("Test-Role", "Temporary")

        Removes management groups and resource groups but only deletes custom role definitions with names containing
        "Test-Role" or "Temporary". Useful when you want to clean up specific custom roles while preserving others.

    .EXAMPLE
        Remove-PlatformLandingZone -ManagementGroups @("alz-test") -DeploymentStacksToDeleteNamePatterns @("alz-", "test-")

        Removes management groups and resource groups but only deletes deployment stacks with names containing
        "alz-" or "test-". Useful when you want to clean up specific deployment stacks while preserving others.

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
        [string[]]$AdditionalSubscriptions = @(),
        [string[]]$ResourceGroupsToRetainNamePatterns = @(
            "VisualStudioOnline-" # By default retain Visual Studio Online resource groups created for Azure DevOps billing purposes
        ),
        [switch]$BypassConfirmation,
        [int]$BypassConfirmationTimeoutSeconds = 30,
        [int]$ThrottleLimit = 11,
        [switch]$PlanMode,
        [switch]$SkipDefenderPlanReset,
        [switch]$SkipDeploymentDeletion,
        [switch]$SkipDeploymentStackDeletion,
        [switch]$SkipOrphanedRoleAssignmentDeletion,
        [switch]$SkipCustomRoleDefinitionDeletion,
        [string[]]$ManagementGroupsToDeleteNamePatterns = @(),
        [string[]]$RoleDefinitionsToDeleteNamePatterns = @(),
        [string[]]$DeploymentStacksToDeleteNamePatterns = @(),
        [switch]$AllowNoManagementGroupMatch,
        [switch]$ForceSubscriptionPlacement
    )

    function Write-ToConsoleLog {
        param (
            [string[]]$Messages,
            [string]$Level = "INFO",
            [System.ConsoleColor]$Color = [System.ConsoleColor]::Blue,
            [switch]$NoNewLine,
            [switch]$Overwrite,
            [switch]$IsError,
            [switch]$IsWarning,
            [switch]$IsSuccess,
            [switch]$IsPlan,
            [switch]$WriteToFile,
            [string]$LogFilePath = $null
        )

        $isDefaultColor = $Color -eq [System.ConsoleColor]::Blue

        if($IsError) {
            $Level = "ERROR"
        } elseif ($IsWarning) {
            $Level = "WARNING"
        } elseif ($IsSuccess) {
            $Level = "SUCCESS"
        } elseif ($IsPlan) {
            $Level = "PLAN"
            $WriteToFile = $true
            $NoNewLine = $true
        }

        if($isDefaultColor) {
            if($Level -eq "ERROR") {
                $Color = [System.ConsoleColor]::Red
            } elseif ($Level -eq "WARNING") {
                $Color = [System.ConsoleColor]::Yellow
            } elseif ($Level -eq "SUCCESS") {
                $Color = [System.ConsoleColor]::Green
            } elseif ($Level -eq "PLAN") {
                $Color = [System.ConsoleColor]::Gray
            }
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $prefix = ""

        if ($Overwrite) {
            $prefix = "`r"
        } else {
            if (-not $NoNewLine) {
                $prefix = [System.Environment]::NewLine
            }
        }

        $finalMessages = @()
        foreach ($Message in $Messages) {
            $finalMessages += "$prefix[$timestamp] [$Level] $Message"
        }

        if($finalMessages.Count -gt 1) {
            $finalMessages = $finalMessages -join "`n"
        }

        Write-Host $finalMessages -ForegroundColor $Color -NoNewline:$Overwrite.IsPresent
        if($WriteToFile -and $LogFilePath) {
            Add-Content -Path $LogFilePath -Value $finalMessages
        }
    }

    function Test-RequiredTooling {
        Write-ToConsoleLog "Checking the software requirements..."

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
            [hashtable]$ManagementGroupsFound = @{},
            [string[]]$ManagementGroupsToDeleteNamePatterns = @()
        )

        $ManagementGroups = $ManagementGroups | Where-Object { $_.type -eq "Microsoft.Management/managementGroups" }

        # Filter management groups at depth 0 (first level children) if patterns are specified
        if ($Depth -eq 0 -and $ManagementGroupsToDeleteNamePatterns.Count -gt 0) {
            $filteredManagementGroups = @()
            foreach($mg in $ManagementGroups) {
                $shouldDelete = $false
                foreach($pattern in $ManagementGroupsToDeleteNamePatterns) {
                    if($mg.name -like "*$pattern*" -or $mg.displayName -like "*$pattern*") {
                        Write-ToConsoleLog "Including management group for deletion due to pattern match '$pattern': $($mg.name) ($($mg.displayName))" -NoNewLine
                        $shouldDelete = $true
                        break
                    }
                }
                if($shouldDelete) {
                    $filteredManagementGroups += $mg
                } else {
                    Write-ToConsoleLog "Skipping management group (no pattern match): $($mg.name) ($($mg.displayName))" -NoNewLine
                }
            }
            $ManagementGroups = $filteredManagementGroups
        }

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
                Get-ManagementGroupChildrenRecursive -ManagementGroups $children -Depth ($Depth + 1) -ManagementGroupsFound $ManagementGroupsFound -ManagementGroupsToDeleteNamePatterns $ManagementGroupsToDeleteNamePatterns
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
            [string]$FinalConfirmationText = "CONFIRM"
        )

        Write-ToConsoleLog "$Message" -IsWarning
        $randomString = (Get-RandomString -Length 6).ToUpper()
        Write-ToConsoleLog "If you wish to proceed, type '$randomString' to confirm." -IsWarning
        $confirmation = Read-Host "Enter the confirmation text"
        $confirmation = $confirmation.ToUpper().Replace("'","").Replace([System.Environment]::NewLine, "").Trim()
        if ($confirmation -ne $randomString.ToUpper()) {
            Write-ToConsoleLog "Confirmation text did not match the required input. Exiting without making any changes." -IsError
            return $false
        }
        Write-ToConsoleLog "Initial confirmation received." -IsSuccess
        Write-ToConsoleLog "This operation is permanent and cannot be reversed!" -IsWarning
        Write-ToConsoleLog "Are you sure you want to proceed? Type '$FinalConfirmationText' to perform the highly destructive operation..." -IsWarning
        $confirmation = Read-Host "Enter the final confirmation text"
        $confirmation = $confirmation.ToUpper().Replace("'","").Replace([System.Environment]::NewLine, "").Trim()
        if ($confirmation -ne $FinalConfirmationText.ToUpper()) {
            Write-ToConsoleLog "Final confirmation did not match the required input. Exiting without making any changes." -IsError
            return $false
        }
        Write-ToConsoleLog "Final confirmation received. Proceeding with destructive operation..." -IsSuccess
        return $true
    }

    function Get-RandomString {
        param (
            [int]$Length = 8
        )

        $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        $string = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
        return $string
    }

    function Remove-OrphanedRoleAssignmentsForScope {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [string]$ScopeType,
            [string]$ScopeNameForLogs,
            [string]$ScopeId,
            [int]$ThrottleLimit,
            [switch]$PlanMode,
            [string]$TempLogFileForPlan
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
                    Write-ToConsoleLog `
                        "Deleting orphaned role assignment: $($roleAssignment.roleDefinitionName) for principal: $($roleAssignment.principalId) from $($ScopeType): $ScopeNameForLogs", `
                        "Would run: az role assignment delete --ids $($roleAssignment.id)" `
                        -IsPlan -LogFilePath $using:TempLogFileForPlan
                } else {
                    $result = az role assignment delete --ids $roleAssignment.id 2>&1
                }

                if (!$result) {
                    Write-ToConsoleLog "Deleted orphaned role assignment: $($roleAssignment.roleDefinitionName) from $($ScopeType): $ScopeNameForLogs" -NoNewLine
                } else {
                    Write-ToConsoleLog "Failed to delete orphaned role assignment: $($roleAssignment.roleDefinitionName) from $($ScopeType): $ScopeNameForLogs", "Full error: $result" -IsWarning -NoNewLine
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
            [switch]$PlanMode,
            [string]$TempLogFileForPlan,
            [switch]$SkipDeploymentStackDeletion,
            [switch]$SkipDeploymentDeletion,
            [string[]]$DeploymentStacksToDeleteNamePatterns = @()
        )

        if(-not $PSCmdlet.ShouldProcess("Delete Deployments", "delete")) {
            return
        }

        $funcWriteToConsoleLog = ${function:Write-ToConsoleLog}.ToString()
        $isSubscriptionScope = $ScopeType -eq "subscription"

        # Delete deployment stacks first (before regular deployments)
        if(-not $SkipDeploymentStackDeletion) {
            Write-ToConsoleLog "Checking for deployment stacks to delete in $($ScopeType): $ScopeNameForLogs" -NoNewLine

            $deploymentStacks = @()
            if ($isSubscriptionScope) {
                $deploymentStacks = (az stack sub list --subscription $ScopeId --query "[].{name:name,id:id}" -o json 2>$null) | ConvertFrom-Json
            } else {
                $deploymentStacks = (az stack mg list --management-group-id $ScopeId --query "[].{name:name,id:id}" -o json 2>$null) | ConvertFrom-Json
            }

            # Filter deployment stacks to only include those matching deletion patterns
            if ($DeploymentStacksToDeleteNamePatterns -and $DeploymentStacksToDeleteNamePatterns.Count -gt 0) {
                $filteredDeploymentStacks = @()
                foreach($stack in $deploymentStacks) {
                    $shouldDelete = $false
                    foreach($pattern in $DeploymentStacksToDeleteNamePatterns) {
                        if($stack.name -like "*$pattern*") {
                            Write-ToConsoleLog "Including deployment stack for deletion due to pattern match '$pattern': $($stack.name)" -NoNewLine
                            $shouldDelete = $true
                            break
                        }
                    }
                    if($shouldDelete) {
                        $filteredDeploymentStacks += $stack
                    } else {
                        Write-ToConsoleLog "Skipping deployment stack (no pattern match): $($stack.name)" -NoNewLine
                    }
                }
                $deploymentStacks = $filteredDeploymentStacks
            }

            if ($deploymentStacks -and $deploymentStacks.Count -gt 0) {
                Write-ToConsoleLog "Found $($deploymentStacks.Count) deployment stack(s) in $($ScopeType): $ScopeNameForLogs" -NoNewLine

                $deploymentStacks | ForEach-Object -Parallel {
                    $deploymentStack = $_
                    $scopeId = $using:ScopeId
                    $scopeNameForLogs = $using:ScopeNameForLogs
                    $scopeType = $using:ScopeType
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                    $isSubscriptionScope = $using:isSubscriptionScope

                    Write-ToConsoleLog "Deleting deployment stack: $($deploymentStack.name) from $($scopeType): $scopeNameForLogs" -NoNewLine
                    $result = $null
                    if($isSubscriptionScope) {
                        if($using:PlanMode) {
                            Write-ToConsoleLog `
                                "Deleting deployment stack: $($deploymentStack.name) from $($scopeType): $scopeNameForLogs", `
                                "Would run: az stack sub delete --subscription $scopeId --name $($deploymentStack.name) --aou detachAll --yes" `
                                -IsPlan -LogFilePath $using:TempLogFileForPlan
                        } else {
                            $result = az stack sub delete --subscription $scopeId --name $deploymentStack.name --aou detachAll --yes 2>&1
                        }
                    } else {
                        if($using:PlanMode) {
                            Write-ToConsoleLog `
                                "Deleting deployment stack: $($deploymentStack.name) from $($scopeType): $scopeNameForLogs", `
                                "Would run: az stack mg delete --management-group-id $scopeId --name $($deploymentStack.name) --aou detachAll --yes" `
                                -IsPlan -LogFilePath $using:TempLogFileForPlan
                        } else {
                            $result = az stack mg delete --management-group-id $scopeId --name $deploymentStack.name --aou detachAll --yes 2>&1
                        }
                    }

                    if (!$result) {
                        Write-ToConsoleLog "Deleted deployment stack: $($deploymentStack.name) from $($scopeType): $scopeNameForLogs" -NoNewLine
                    } else {
                        Write-ToConsoleLog "Failed to delete deployment stack: $($deploymentStack.name) from $($scopeType): $scopeNameForLogs", "Full error: $result" -IsWarning -NoNewLine
                    }
                } -ThrottleLimit $ThrottleLimit

                Write-ToConsoleLog "All deployment stacks processed in $($ScopeType): $ScopeNameForLogs" -NoNewLine
            } else {
                Write-ToConsoleLog "No deployment stacks found in $($ScopeType): $ScopeNameForLogs, skipping." -NoNewLine
            }
        } else {
            Write-ToConsoleLog "Skipping deployment stack deletion in $($ScopeType): $ScopeNameForLogs" -NoNewLine
        }

        if(-not $SkipDeploymentDeletion) {
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
                    $isSubscriptionScope = $using:isSubscriptionScope

                    Write-ToConsoleLog "Deleting deployment: $deploymentName from $($scopeType): $scopeNameForLogs" -NoNewLine
                    $result = $null
                    if($isSubscriptionScope) {
                        if($using:PlanMode) {
                            Write-ToConsoleLog `
                                "Deleting deployment: $deploymentName from $($scopeType): $scopeNameForLogs", `
                                "Would run: az deployment sub delete --subscription $scopeId --name $deploymentName" `
                                -IsPlan -LogFilePath $using:TempLogFileForPlan
                        } else {
                            $result = az deployment sub delete --subscription $scopeId --name $deploymentName 2>&1
                        }
                    } else {
                        if($using:PlanMode) {
                            Write-ToConsoleLog `
                                "Deleting deployment: $deploymentName from $($scopeType): $scopeNameForLogs", `
                                "Would run: az deployment mg delete --management-group-id $scopeId --name $deploymentName" `
                                -IsPlan -LogFilePath $using:TempLogFileForPlan
                        } else {
                            $result = az deployment mg delete --management-group-id $scopeId --name $deploymentName 2>&1
                        }
                    }

                    if (!$result) {
                        Write-ToConsoleLog "Deleted deployment: $deploymentName from $($scopeType): $scopeNameForLogs" -NoNewLine
                    } else {
                        Write-ToConsoleLog "Failed to delete deployment: $deploymentName from $($scopeType): $scopeNameForLogs", "Full error: $result" -IsWarning -NoNewLine
                    }
                } -ThrottleLimit $ThrottleLimit

                Write-ToConsoleLog "All deployments processed in $($scopeType): $scopeNameForLogs" -NoNewLine
            } else {
                Write-ToConsoleLog "No deployments found in $($scopeType): $scopeNameForLogs, skipping." -NoNewLine
            }
        } else {
            Write-ToConsoleLog "Skipping deployment deletion in $($ScopeType): $ScopeNameForLogs" -NoNewLine
        }
    }

    function Remove-CustomRoleDefinitionsForScope {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [string]$ManagementGroupId,
            [string]$ManagementGroupDisplayName,
            [int]$ThrottleLimit,
            [switch]$PlanMode,
            [string]$TempLogFileForPlan,
            [string[]]$RoleDefinitionsToDeleteNamePatterns = @()
        )

        if(-not $PSCmdlet.ShouldProcess("Delete Custom Role Definitions", "delete")) {
            return
        }

        $funcWriteToConsoleLog = ${function:Write-ToConsoleLog}.ToString()

        Write-ToConsoleLog "Checking for custom role definitions on management group: $ManagementGroupId ($ManagementGroupDisplayName)" -NoNewLine

        # Get all custom role definitions scoped to this management group
        $customRoleDefinitions = (az role definition list --custom-role-only true --scope "/providers/Microsoft.Management/managementGroups/$ManagementGroupId" --query "[].{name:name,roleName:roleName,id:id,assignableScopes:assignableScopes}" -o json) | ConvertFrom-Json

        $customRoleDefinitions = $customRoleDefinitions | Where-Object {
            $_.assignableScopes -contains "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"
        }

        # Filter role definitions to only include those matching deletion patterns
        if ($RoleDefinitionsToDeleteNamePatterns -and $RoleDefinitionsToDeleteNamePatterns.Count -gt 0) {
            $filteredRoleDefinitions = @()
            foreach($roleDef in $customRoleDefinitions) {
                $shouldDelete = $false
                foreach($pattern in $RoleDefinitionsToDeleteNamePatterns) {
                    if($roleDef.roleName -like "*$pattern*") {
                        Write-ToConsoleLog "Including custom role definition for deletion due to pattern match '$pattern': $($roleDef.roleName) (ID: $($roleDef.name))" -NoNewLine
                        $shouldDelete = $true
                        break
                    }
                }
                if($shouldDelete) {
                    $filteredRoleDefinitions += $roleDef
                } else {
                    Write-ToConsoleLog "Skipping custom role definition (no pattern match): $($roleDef.roleName) (ID: $($roleDef.name))" -NoNewLine
                }
            }
            $customRoleDefinitions = $filteredRoleDefinitions
        }

        if (-not $customRoleDefinitions -or $customRoleDefinitions.Count -eq 0) {
            Write-ToConsoleLog "No custom role definitions found on management group: $ManagementGroupId ($ManagementGroupDisplayName), skipping." -NoNewLine
            return
        }

        Write-ToConsoleLog "Found $($customRoleDefinitions.Count) custom role definition(s) on management group: $ManagementGroupId ($ManagementGroupDisplayName)" -NoNewLine

        # For each custom role definition, find and delete all assignments using Resource Graph, then delete the definition
        foreach ($roleDefinition in $customRoleDefinitions) {
            $graphExtension = az extension show --name resource-graph 2>$null
            if (-not $graphExtension) {
                Write-ToConsoleLog "Installing Azure Resource Graph extension for role assignment queries..." -NoNewLine -IsWarning
                az config set extension.dynamic_install_allow_preview=true 2>$null
                az extension add --name resource-graph 2>$null
            }

            Write-ToConsoleLog "Processing custom role definition: $($roleDefinition.roleName) (ID: $($roleDefinition.name))" -NoNewLine

            # Use Resource Graph to find all role assignments for this custom role definition across all scopes
            $resourceGraphQuery = "authorizationresources | where type == 'microsoft.authorization/roleassignments' | where properties.roleDefinitionId == '/providers/Microsoft.Authorization/RoleDefinitions/$($roleDefinition.name)' | project id, name, properties"
            $roleAssignments = (az graph query -q $resourceGraphQuery --query "data" --management-groups $ManagementGroupId -o json) | ConvertFrom-Json

            if ($roleAssignments -and $roleAssignments.Count -gt 0) {
                Write-ToConsoleLog "Found $($roleAssignments.Count) role assignment(s) for custom role '$($roleDefinition.roleName)'" -NoNewLine

                $roleAssignments | ForEach-Object -Parallel {
                    $assignment = $_
                    $roleDefinitionName = $using:roleDefinition.roleName
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog

                    Write-ToConsoleLog "Deleting role assignment '$($assignment.name)' of custom role '$roleDefinitionName' for principal: $($assignment.properties.principalId)" -NoNewLine

                    if($using:PlanMode) {
                        Write-ToConsoleLog `
                            "Deleting role assignment '$($assignment.name)' of custom role '$roleDefinitionName' for principal: $($assignment.properties.principalId)", `
                            "Would run: az role assignment delete --ids $($assignment.id)" `
                            -IsPlan -LogFilePath $using:TempLogFileForPlan
                    } else {
                        $result = az role assignment delete --ids $assignment.id 2>&1
                        if (!$result) {
                            Write-ToConsoleLog "Deleted role assignment '$($assignment.name)' of custom role '$roleDefinitionName'" -NoNewLine
                        } else {
                            Write-ToConsoleLog "Failed to delete role assignment '$($assignment.name)' of custom role '$roleDefinitionName'", "Full error: $result" -IsWarning -NoNewLine
                        }
                    }
                } -ThrottleLimit $using:ThrottleLimit
            } else {
                Write-ToConsoleLog "No role assignments found for custom role '$($roleDefinition.roleName)'" -NoNewLine
            }

            # Now delete the custom role definition itself
            Write-ToConsoleLog "Deleting custom role definition: $($roleDefinition.roleName) (ID: $($roleDefinition.name))" -NoNewLine

            if($PlanMode) {
                Write-ToConsoleLog `
                    "Deleting custom role definition: $($roleDefinition.roleName) (ID: $($roleDefinition.name))", `
                    "Would run: az role definition delete --name $($roleDefinition.name) --scope `"/providers/Microsoft.Management/managementGroups/$ManagementGroupId`"" `
                    -IsPlan -LogFilePath $TempLogFileForPlan
            } else {
                $result = az role definition delete --name $roleDefinition.name --scope "/providers/Microsoft.Management/managementGroups/$ManagementGroupId" 2>&1
                if (!$result) {
                    Write-ToConsoleLog "Deleted custom role definition: $($roleDefinition.roleName) (ID: $($roleDefinition.name))" -NoNewLine
                } else {
                    Write-ToConsoleLog "Failed to delete custom role definition: $($roleDefinition.roleName) (ID: $($roleDefinition.name))", "Full error: $result" -IsWarning -NoNewLine
                }
            }
        }

        Write-ToConsoleLog "All custom role definitions processed for management group: $ManagementGroupId ($ManagementGroupDisplayName)" -NoNewLine
    }

    # Main execution starts here
    if ($PSCmdlet.ShouldProcess("Delete Management Groups and Clean Subscriptions", "delete")) {

        Test-RequiredTooling

        Write-ToConsoleLog "This cmdlet uses preview features of the Azure CLI. By continuing, you agree to install preview extensions." -IsWarning

        $TempLogFileForPlan = ""
        if($PlanMode) {
            Write-ToConsoleLog "Plan Mode enabled, no changes will be made. All actions will be logged as what would be performed." -IsWarning
            $TempLogFileForPlan = (New-TemporaryFile).FullName
        }

        $funcWriteToConsoleLog = ${function:Write-ToConsoleLog}.ToString()
        $funcRemoveOrphanedRoleAssignmentsForScope = ${function:Remove-OrphanedRoleAssignmentsForScope}.ToString()
        $funcRemoveDeploymentsForScope = ${function:Remove-DeploymentsForScope}.ToString()
        $funcRemoveCustomRoleDefinitionsForScope = ${function:Remove-CustomRoleDefinitionsForScope}.ToString()

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

            # Query all management groups in the tenant first
            $allManagementGroups = (az account management-group list --query "[].{name:name,displayName:displayName}" -o json) | ConvertFrom-Json

            foreach($managementGroup in $ManagementGroups) {
                # Treat $managementGroup as a regex and match against name or displayName
                $matchingMgs = $allManagementGroups | Where-Object { $_.name -match $managementGroup -or $_.displayName -match $managementGroup }

                if($null -eq $matchingMgs -or $matchingMgs.Count -eq 0) {
                    Write-ToConsoleLog "Management group not found matching pattern: $managementGroup" -IsWarning
                    continue
                }

                foreach($matchedMg in $matchingMgs) {
                    Write-ToConsoleLog "Found management group matching pattern '$managementGroup': $($matchedMg.name) ($($matchedMg.displayName))" -NoNewLine
                    $managementGroupsFound += @{
                        Name        = $matchedMg.name
                        DisplayName = $matchedMg.displayName
                    }
                }
            }

            if($managementGroupsFound.Count -eq 0) {
                if($AllowNoManagementGroupMatch) {
                    Write-ToConsoleLog "No valid management groups found from the provided list, but continuing due to -AllowNoManagementGroupMatch..." -IsWarning
                } else {
                    Write-ToConsoleLog "No valid management groups found from the provided list, exiting..." -IsError
                    return
                }
            }

            if(-not $BypassConfirmation) {
                Write-ToConsoleLog "The following Management Groups will be processed for removal:"
                $managementGroupsFound | ForEach-Object { Write-ToConsoleLog "Management Group: $($_.Name) ($($_.DisplayName))" -NoNewLine }

                if($PlanMode) {
                    Write-ToConsoleLog "Skipping confirmation for plan mode"
                } else {
                    $warningMessage = "ALL THE MANAGEMENT GROUP STRUCTURES ONE LEVEL BELOW THE LISTED MANAGEMENT GROUPS WILL BE PERMANENTLY DELETED"
                    if($DeleteTargetManagementGroups) {
                        $warningMessage = "ALL THE LISTED MANAGEMENTS GROUPS AND THEIR CHILDREN WILL BE PERMANENTLY DELETED"
                    }
                    $continue = Invoke-PromptForConfirmation -message $warningMessage
                    if(-not $continue) {
                        Write-ToConsoleLog "Exiting..."
                        return
                    }
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
                    $TempLogFileForPlan = $using:TempLogFileForPlan

                    $managementGroupId = $_.Name
                    $managementGroupDisplayName = $_.DisplayName

                    Write-ToConsoleLog "Finding management group: $managementGroupId ($managementGroupDisplayName)" -NoNewLine
                    $topLevelManagementGroup = (az account management-group show --name $managementGroupId --expand --recurse) | ConvertFrom-Json

                    $hasChildren = $topLevelManagementGroup.children -and $topLevelManagementGroup.children.Count -gt 0

                    $managementGroupsToDelete = @{}

                    $targetManagementGroups = $deleteTargetManagementGroups ? @($topLevelManagementGroup) : @($topLevelManagementGroup.children)

                    if($hasChildren -or $deleteTargetManagementGroups) {
                        ${function:Get-ManagementGroupChildrenRecursive} = $using:funcGetManagementGroupChildrenRecursive
                        $patternsToUse = $deleteTargetManagementGroups ? @() : $using:ManagementGroupsToDeleteNamePatterns
                        $managementGroupsToDelete = Get-ManagementGroupChildrenRecursive -ManagementGroups @($targetManagementGroups) -ManagementGroupsToDeleteNamePatterns $patternsToUse
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
                                        Write-ToConsoleLog "Moving subscription from management group $_ to target management group: $($subscriptionsTargetManagementGroup), subscription: $($subscription.displayName)" -NoNewLine
                                        if($using:PlanMode) {
                                            Write-ToConsoleLog `
                                                "Moving subscription from management group $_ to target management group: $($subscriptionsTargetManagementGroup), subscription: $($subscription.displayName)", `
                                                "Would run: az account management-group subscription add --name $($subscriptionsTargetManagementGroup) --subscription $($subscription.name)" `
                                                -IsPlan -LogFilePath $using:TempLogFileForPlan
                                        } else {
                                            $result = (az account management-group subscription add --name $subscriptionsTargetManagementGroup --subscription $subscription.name 2>&1)
                                            if($result -and $result.ToLower().Contains("Error")) {
                                                Write-ToConsoleLog "Failed to move subscription to target management group: $($subscriptionsTargetManagementGroup), subscription: $($subscription.displayName)", "Full error: $result" -IsWarning -NoNewLine
                                            } else {
                                                Write-ToConsoleLog "Moved subscription to target management group: $($subscriptionsTargetManagementGroup), subscription: $($subscription.displayName)" -NoNewLine
                                            }
                                        }
                                    } else {
                                        Write-ToConsoleLog "Removing subscription from management group $($_): $($subscription.displayName)" -NoNewLine
                                        if($using:PlanMode) {
                                            Write-ToConsoleLog `
                                                "Removing subscription from management group $($_): $($subscription.displayName)", `
                                                "Would run: az account management-group subscription remove --name $_ --subscription $($subscription.name)" `
                                                -IsPlan -LogFilePath $using:TempLogFileForPlan
                                        } else {
                                            $result = (az account management-group subscription remove --name $_ --subscription $subscription.name 2>&1)
                                            if($result -and $result.ToLower().Contains("Error")) {
                                                Write-ToConsoleLog "Failed to remove subscription from management group: $_, subscription: $($subscription.displayName)", "Full error: $result" -IsWarning -NoNewLine
                                            } else {
                                                Write-ToConsoleLog "Removed subscription from management group: $_, subscription: $($subscription.displayName)" -NoNewLine
                                            }
                                        }
                                    }
                                }
                            } else {
                                Write-ToConsoleLog "Management group has no subscriptions: $_" -NoNewline
                            }

                            Write-ToConsoleLog "Deleting management group: $_" -NoNewline
                            if($using:PlanMode) {
                                Write-ToConsoleLog `
                                    "Deleting management group: $_", `
                                    "Would run: az account management-group delete --name $_" `
                                    -IsPlan -LogFilePath $using:TempLogFileForPlan
                            } else {
                                $result = (az account management-group delete --name $_ 2>&1)
                                if($result -like "*Error*") {
                                    Write-ToConsoleLog "Failed to delete management group: $_", "Full error: $result" -IsWarning -NoNewline
                                } else {
                                    Write-ToConsoleLog "Deleted management group: $_" -NoNewline
                                }
                            }
                        } -ThrottleLimit $using:ThrottleLimit
                    }
                } -ThrottleLimit $ThrottleLimit
            }

            # Delete deployments and deployment stacks from target management groups that are not being deleted
            if($managementGroupsFound.Count -ne 0 -and (-not $SkipDeploymentDeletion -or -not $SkipDeploymentStackDeletion) -and -not $DeleteTargetManagementGroups) {
                $managementGroupsFound | ForEach-Object -Parallel {
                    $managementGroupId = $_.Name
                    $managementGroupDisplayName = $_.DisplayName
                    $deleteTargetManagementGroups = $using:DeleteTargetManagementGroups
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                    $funcRemoveDeploymentsForScope = $using:funcRemoveDeploymentsForScope
                    ${function:Remove-DeploymentsForScope} = $funcRemoveDeploymentsForScope

                    Remove-DeploymentsForScope `
                        -ScopeType "management group" `
                        -ScopeNameForLogs "$managementGroupId ($managementGroupDisplayName)" `
                        -ScopeId $managementGroupId `
                        -ThrottleLimit $using:ThrottleLimit `
                        -PlanMode:$using:PlanMode `
                        -TempLogFileForPlan $using:TempLogFileForPlan `
                        -SkipDeploymentStackDeletion:$using:SkipDeploymentStackDeletion `
                        -SkipDeploymentDeletion:$using:SkipDeploymentDeletion `
                        -DeploymentStacksToDeleteNamePatterns $using:DeploymentStacksToDeleteNamePatterns

                } -ThrottleLimit $ThrottleLimit
            } else {
                Write-ToConsoleLog "Skipping deployment and deployment stack deletion for management groups" -NoNewLine
            }

            # Delete orphaned role assignments from target management groups that are not being deleted
            if($managementGroupsFound.Count -ne 0 -and -not $SkipOrphanedRoleAssignmentDeletion -and -not $DeleteTargetManagementGroups) {
                $managementGroupsFound | ForEach-Object -Parallel {
                    $managementGroupId = $_.Name
                    $managementGroupDisplayName = $_.DisplayName
                    $deleteTargetManagementGroups = $using:DeleteTargetManagementGroups
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                    $funcRemoveOrphanedRoleAssignmentsForScope = $using:funcRemoveOrphanedRoleAssignmentsForScope
                    ${function:Remove-OrphanedRoleAssignmentsForScope} = $funcRemoveOrphanedRoleAssignmentsForScope

                    Remove-OrphanedRoleAssignmentsForScope `
                        -ScopeType "management group" `
                        -ScopeNameForLogs "$managementGroupId ($managementGroupDisplayName)" `
                        -ScopeId $managementGroupId `
                        -ThrottleLimit $using:ThrottleLimit `
                        -PlanMode:$using:PlanMode `
                        -TempLogFileForPlan $using:TempLogFileForPlan

                } -ThrottleLimit $ThrottleLimit
            } else {
                Write-ToConsoleLog "Skipping orphaned role assignment deletion for management groups" -NoNewLine
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

        # Add additional subscriptions to the discovered/supplied subscriptions
        if($AdditionalSubscriptions.Count -gt 0) {
            Write-ToConsoleLog "Processing additional subscriptions to merge with discovered/supplied subscriptions..."

            foreach($subscription in $AdditionalSubscriptions) {
                $subscriptionObject = @{
                    Id   = (Test-IsGuid -StringGuid $subscription) ? $subscription : (az account list --all --query "[?name=='$subscription'].id" -o tsv)
                    Name = (Test-IsGuid -StringGuid $subscription) ? (az account list --all --query "[?id=='$subscription'].name" -o tsv) : $subscription
                }
                if(-not $subscriptionObject.Id -or -not $subscriptionObject.Name) {
                    Write-ToConsoleLog "Additional subscription not found, skipping: $subscription" -IsWarning
                    continue
                }
                Write-ToConsoleLog "Adding additional subscription: $($subscriptionObject.Name) (ID: $($subscriptionObject.Id))" -NoNewLine
                $subscriptionsFound.Add($subscriptionObject)
            }
        }

        $subscriptionsFinal = $subscriptionsFound.ToArray() | Sort-Object -Property name -Unique

        # Force subscription placement if requested
        if($ForceSubscriptionPlacement -and $subscriptionsFinal.Count -gt 0) {
            $targetManagementGroupForPlacement = $SubscriptionsTargetManagementGroup

            if(-not $targetManagementGroupForPlacement) {
                # Get default management group from hierarchy settings
                $tenantId = (az account show --query "tenantId" -o tsv)
                $hierarchySettings = (az account management-group hierarchy-settings list --name $tenantId -o json 2>$null) | ConvertFrom-Json
                if($hierarchySettings -and $hierarchySettings.value.defaultManagementGroup) {
                    $targetManagementGroupForPlacement = $hierarchySettings.value.defaultManagementGroup
                    Write-ToConsoleLog "No target management group specified, using default management group from hierarchy settings: $targetManagementGroupForPlacement" -IsWarning
                } else {
                    # Fall back to tenant root if no default is configured
                    $targetManagementGroupForPlacement = $tenantId
                    Write-ToConsoleLog "No default management group configured in hierarchy settings, using tenant root: $targetManagementGroupForPlacement" -IsWarning
                }
            }

            if($targetManagementGroupForPlacement) {
                Write-ToConsoleLog "Force subscription placement enabled, moving subscriptions to management group: $targetManagementGroupForPlacement" -NoNewLine

                $subscriptionsFinal | ForEach-Object -Parallel {
                    $subscription = $_
                    $targetMg = $using:targetManagementGroupForPlacement
                    $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                    ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                    $TempLogFileForPlan = $using:TempLogFileForPlan

                    Write-ToConsoleLog "Moving subscription to management group: $targetMg, subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                    if($using:PlanMode) {
                        Write-ToConsoleLog `
                            "Moving subscription to management group: $targetMg, subscription: $($subscription.Name) (ID: $($subscription.Id))", `
                            "Would run: az account management-group subscription add --name $targetMg --subscription $($subscription.Id)" `
                            -IsPlan -LogFilePath $TempLogFileForPlan
                    } else {
                        az account management-group subscription add --name $targetMg --subscription $subscription.Id 2>&1 | Out-Null
                        Write-ToConsoleLog "Subscription placed in management group: $targetMg, subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                    }
                } -ThrottleLimit $ThrottleLimit

                Write-ToConsoleLog "Forced subscription placement completed." -IsSuccess
            }
        }

        if($subscriptionsFinal.Count -eq 0) {
            Write-ToConsoleLog "No subscriptions provided or found, skipping resource group deletion..." -IsWarning
        } else {
            if(-not $BypassConfirmation) {
                Write-ToConsoleLog "The following Subscriptions were provided or discovered during management group cleanup:"
                $subscriptionsFinal | ForEach-Object { Write-ToConsoleLog "Name: $($_.Name), ID: $($_.Id)" -NoNewline }

                if($PlanMode) {
                    Write-ToConsoleLog "Skipping confirmation for plan mode"
                } else {
                    $continue = Invoke-PromptForConfirmation -Message "ALL RESOURCE GROUPS IN THE LISTED SUBSCRIPTIONS WILL BE PERMANENTLY DELETED UNLESS THEY MATCH RETENTION PATTERNS"
                    if(-not $continue) {
                        Write-ToConsoleLog "Exiting..."
                        return
                    }
                }
            }
        }

        if($subscriptionsFinal.Count -ne 0) {
            $subscriptionsFinal | ForEach-Object -Parallel {
                $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                $funcRemoveOrphanedRoleAssignmentsForScope = $using:funcRemoveOrphanedRoleAssignmentsForScope
                ${function:Remove-OrphanedRoleAssignmentsForScope} = $funcRemoveOrphanedRoleAssignmentsForScope
                $funcRemoveDeploymentsForScope = $using:funcRemoveDeploymentsForScope
                ${function:Remove-DeploymentsForScope} = $funcRemoveDeploymentsForScope
                $TempLogFileForPlan = $using:TempLogFileForPlan
                $throttleLimit = $using:ThrottleLimit
                $planMode = $using:PlanMode

                $subscription = $_
                Write-ToConsoleLog "Finding resource groups for subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewline

                $resourceGroups = (az group list --subscription $subscription.Id) | ConvertFrom-Json

                if ($resourceGroups.Count -eq 0) {
                    Write-ToConsoleLog "No resource groups found for subscription: $($subscription.Name) (ID: $($subscription.Id)), skipping." -NoNewline
                } else {
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
                                Write-ToConsoleLog `
                                    "Deleting resource group for subscription: $($subscription.Name) (ID: $($subscription.Id)), resource group: $($ResourceGroupName)", `
                                    "Would run: az group delete --name $ResourceGroupName --subscription $($subscription.Id) --yes" `
                                    -IsPlan -LogFilePath $using:TempLogFileForPlan
                            } else {
                                $result = az group delete --name $ResourceGroupName --subscription $subscription.Id --yes 2>&1
                            }

                            if (!$result) {
                                Write-ToConsoleLog "Deleted resource group for subscription: $($subscription.Name) (ID: $($subscription.Id)), resource group: $($ResourceGroupName)" -NoNewLine
                            } else {
                                Write-ToConsoleLog "Delete resource group failed for subscription: $($subscription.Name) (ID: $($subscription.Id)), resource group: $($ResourceGroupName)", "Full error: $result" -NoNewLine
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
                }

                if(-not $using:SkipDefenderPlanReset) {
                    Write-ToConsoleLog "Checking for Microsoft Defender for Cloud Plans to reset in subscription: $($subscription.Name) (ID: $($subscription.Id))"
                    $defenderPlans = (az security pricing list --subscription $subscription.Id 2>$null) | ConvertFrom-Json

                    $defenderPlans.value | Where-Object { -not $_.deprecated } | ForEach-Object -Parallel {
                        $subscription = $using:subscription
                        $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                        ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog

                        if ($_.pricingTier -ne "Free") {
                            Write-ToConsoleLog "Resetting Microsoft Defender for Cloud Plan to Free for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                            $result = $null
                            if($using:PlanMode) {
                                Write-ToConsoleLog `
                                    "Resetting Microsoft Defender for Cloud Plan to Free for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))", `
                                    "Would run: az security pricing create --name $($_.name) --tier `"Free`" --subscription $($subscription.Id)" `
                                    -IsPlan -LogFilePath $using:TempLogFileForPlan
                            } else {
                                $result = (az security pricing create --name $_.name --tier "Free" --subscription $subscription.Id 2>&1)
                            }
                            if ($result -like "*must be 'Standard'*") {
                                Write-ToConsoleLog "Resetting Microsoft Defender for Cloud Plan to Standard as Free is not supported for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                                if($using:PlanMode) {
                                    Write-ToConsoleLog `
                                        "Resetting Microsoft Defender for Cloud Plan to Standard for plan: $($_.name) in subscription: $($subscription.Name) (ID: $($subscription.Id))", `
                                        "Would run: az security pricing create --name $($_.name) --tier `"Standard`" --subscription $($subscription.Id)" `
                                        -IsPlan -LogFilePath $using:TempLogFileForPlan
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

                if(-not $using:SkipDeploymentDeletion -or -not $using:SkipDeploymentStackDeletion) {
                    Remove-DeploymentsForScope `
                        -ScopeType "subscription" `
                        -ScopeNameForLogs "$($subscription.Name) (ID: $($subscription.Id))" `
                        -ScopeId $subscription.Id `
                        -ThrottleLimit $using:ThrottleLimit `
                        -PlanMode:$using:PlanMode `
                        -TempLogFileForPlan $using:TempLogFileForPlan `
                        -SkipDeploymentStackDeletion:$using:SkipDeploymentStackDeletion `
                        -SkipDeploymentDeletion:$using:SkipDeploymentDeletion `
                        -DeploymentStacksToDeleteNamePatterns $using:DeploymentStacksToDeleteNamePatterns
                } else {
                    Write-ToConsoleLog "Skipping subscription level deployment and deployment stack deletion in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                }

                if(-not $using:SkipOrphanedRoleAssignmentDeletion) {
                    Remove-OrphanedRoleAssignmentsForScope `
                        -ScopeType "subscription" `
                        -ScopeNameForLogs "$($subscription.Name) (ID: $($subscription.Id))" `
                        -ScopeId $subscription.Id `
                        -ThrottleLimit $using:ThrottleLimit `
                        -PlanMode:$using:PlanMode `
                        -TempLogFileForPlan $using:TempLogFileForPlan
                } else {
                    Write-ToConsoleLog "Skipping orphaned role assignment deletion in subscription: $($subscription.Name) (ID: $($subscription.Id))" -NoNewLine
                }

            } -ThrottleLimit $ThrottleLimit
        }

        # Delete custom role definitions from target management groups that are not being deleted
        if($managementGroupsFound.Count -ne 0 -and -not $SkipCustomRoleDefinitionDeletion -and -not $DeleteTargetManagementGroups) {
            $managementGroupsFound | ForEach-Object -Parallel {
                $managementGroupId = $_.Name
                $managementGroupDisplayName = $_.DisplayName
                $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                $funcRemoveCustomRoleDefinitionsForScope = $using:funcRemoveCustomRoleDefinitionsForScope
                ${function:Remove-CustomRoleDefinitionsForScope} = $funcRemoveCustomRoleDefinitionsForScope

                Remove-CustomRoleDefinitionsForScope `
                    -ManagementGroupId $managementGroupId `
                    -ManagementGroupDisplayName $managementGroupDisplayName `
                    -ThrottleLimit $using:ThrottleLimit `
                    -PlanMode:$using:PlanMode `
                    -TempLogFileForPlan $using:TempLogFileForPlan `
                    -RoleDefinitionsToDeleteNamePatterns $using:RoleDefinitionsToDeleteNamePatterns

            } -ThrottleLimit $ThrottleLimit
        } else {
            Write-ToConsoleLog "Skipping custom role definition deletion for management groups" -NoNewLine
        }

        Write-ToConsoleLog "Cleanup completed." -IsSuccess

        if($PlanMode) {
            Write-ToConsoleLog "Plan mode enabled, no changes were made." -IsWarning
            $planLogContents = Get-Content -Path $TempLogFileForPlan -Raw
            Write-ToConsoleLog "Plan mode log contents:`n$planLogContents" -Color Gray
            Remove-Item -Path $TempLogFileForPlan -Force
        }
    }
}
