function Remove-AzureDevOpsAccelerator {
    <#
    .SYNOPSIS
        Removes Azure DevOps resources created by the Azure Landing Zone accelerator bootstrap modules.

    .DESCRIPTION
        The Remove-AzureDevOpsAccelerator function performs cleanup of Azure DevOps resources that were created
        by the Azure Landing Zone accelerator bootstrap process (https://github.com/Azure/accelerator-bootstrap-modules).
        This includes projects and optionally agent pools.

        The function operates in the following sequence:
        1. Validates Azure CLI and Azure DevOps extension authentication
        2. Prompts for confirmation (unless bypassed or in plan mode)
        3. Discovers and deletes projects matching the specified patterns
        4. Optionally discovers and deletes agent pools matching the specified patterns

        CRITICAL WARNING: This is a highly destructive operation that will permanently delete Azure DevOps resources.
        Use with extreme caution and ensure you have appropriate backups and authorization before executing.

    .PARAMETER AzureDevOpsOrganization
        The Azure DevOps organization URL or name. Can be provided as either the full URL
        (e.g., https://dev.azure.com/my-org) or just the organization name (e.g., my-org).
        This parameter is required.

    .PARAMETER ProjectNamePatterns
        An array of regex patterns to match against project names. Projects matching any of these
        patterns will be deleted. If empty, no projects will be deleted.
        Default: Empty array (no projects deleted)

    .PARAMETER AgentPoolNamePatterns
        An array of regex patterns to match against agent pool names. Agent pools matching any of
        these patterns will be deleted. If empty, no agent pools will be deleted. Requires the
        -IncludeAgentPools switch to be specified.
        Default: Empty array (no agent pools deleted)

    .PARAMETER IncludeAgentPools
        A switch parameter that enables deletion of agent pools matching the patterns specified in
        -AgentPoolNamePatterns. By default, agent pools are not deleted. This is useful for cleaning
        up self-hosted agent pools created during the bootstrap process.
        Default: $false (do not delete agent pools)

    .PARAMETER BypassConfirmation
        A switch parameter that bypasses the interactive confirmation prompts. When specified, the function
        waits for the duration specified in -BypassConfirmationTimeoutSeconds before proceeding, allowing
        time to cancel. During this timeout, pressing any key will cancel the operation.
        WARNING: Use this parameter with extreme caution as it reduces safety checks.
        Default: $false (confirmation required)

    .PARAMETER BypassConfirmationTimeoutSeconds
        The number of seconds to wait before proceeding when -BypassConfirmation is used. During this
        timeout, pressing any key will cancel the operation. This provides a safety window to prevent
        accidental deletions.
        Default: 30 seconds

    .PARAMETER ThrottleLimit
        The maximum number of parallel operations to execute simultaneously. This controls the degree
        of parallelism when processing resources. Higher values may improve performance but increase
        API throttling risk.
        Default: 11

    .PARAMETER PlanMode
        A switch parameter that enables "dry run" mode. When specified, the function displays what
        actions would be taken without actually making any changes. This is useful for validating
        the scope of operations before executing the actual cleanup.
        Default: $false (execute actual deletions)

    .EXAMPLE
        Remove-AzureDevOpsAccelerator -AzureDevOpsOrganization "my-org" -ProjectNamePatterns @("^alz-.*") -PlanMode

        Shows what projects matching the pattern "^alz-.*" would be deleted from the "my-org"
        organization without making any changes.

    .EXAMPLE
        Remove-AzureDevOpsAccelerator -AzureDevOpsOrganization "https://dev.azure.com/my-org" -ProjectNamePatterns @("^alz-.*")

        Deletes all projects matching the pattern "^alz-.*" from the "my-org" organization.

    .EXAMPLE
        Remove-AzureDevOpsAccelerator -AzureDevOpsOrganization "my-org" -ProjectNamePatterns @("^alz-.*") -IncludeAgentPools -AgentPoolNamePatterns @("^alz-.*")

        Deletes projects and self-hosted agent pools matching the pattern "^alz-.*" from the
        "my-org" organization.

    .EXAMPLE
        Remove-AzureDevOpsAccelerator -AzureDevOpsOrganization "my-org" -ProjectNamePatterns @("^test-alz$") -BypassConfirmation -BypassConfirmationTimeoutSeconds 10

        Deletes the project named exactly "test-alz" with a 10-second confirmation bypass timeout.

    .NOTES
        This function requires the Azure CLI with the Azure DevOps extension to be installed and authenticated.
        Install Azure CLI: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
        Install Azure DevOps extension: az extension add --name azure-devops
        Authenticate: az devops login (supports PAT authentication, az login is not required)

        Required permissions:
        - Project Collection Administrator or equivalent permissions to delete projects
        - Agent Pool Administrator permissions to delete agent pools
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "[REQUIRED] The Azure DevOps organization URL or name.")]
        [Alias("org")]
        [string]$AzureDevOpsOrganization,

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Regex patterns to match project names for deletion.")]
        [Alias("projects")]
        [string[]]$ProjectNamePatterns = @(),

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Regex patterns to match agent pool names for deletion.")]
        [Alias("pools")]
        [string[]]$AgentPoolNamePatterns = @(),

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Include agent pools in the deletion process.")]
        [switch]$IncludeAgentPools,

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Bypass interactive confirmation prompts.")]
        [switch]$BypassConfirmation,

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Seconds to wait when bypassing confirmation.")]
        [int]$BypassConfirmationTimeoutSeconds = 30,

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Maximum parallel operations.")]
        [int]$ThrottleLimit = 11,

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Enable dry run mode - no changes will be made.")]
        [switch]$PlanMode
    )

    function Get-NormalizedOrganizationUrl {
        param (
            [string]$Organization
        )

        # If it's already a URL, return it
        if ($Organization -match "^https?://") {
            return $Organization.TrimEnd('/')
        }

        # Otherwise, construct the URL
        return "https://dev.azure.com/$Organization"
    }

    # Main execution starts here
    if ($PSCmdlet.ShouldProcess("Delete Azure DevOps Resources", "delete")) {

        Test-Tooling -Checks @("AzureDevOpsCli")

        $TempLogFileForPlan = ""
        if($PlanMode) {
            Write-ToConsoleLog "Plan Mode enabled, no changes will be made. All actions will be logged as what would be performed." -IsWarning
            $TempLogFileForPlan = (New-TemporaryFile).FullName
        }

        $funcWriteToConsoleLog = ${function:Write-ToConsoleLog}.ToString()

        # Normalize organization URL
        $organizationUrl = Get-NormalizedOrganizationUrl -Organization $AzureDevOpsOrganization
        Write-ToConsoleLog "Using Azure DevOps organization: $organizationUrl" -NoNewLine

        # Configure Azure DevOps CLI defaults
        az devops configure --defaults organization=$organizationUrl 2>&1 | Out-Null

        if($BypassConfirmation) {
            Write-ToConsoleLog "Bypass confirmation enabled, proceeding without prompts..." -IsWarning
            Write-ToConsoleLog "This is a highly destructive operation that will permanently delete Azure DevOps resources!" -IsWarning
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

        $hasProjectPatterns = $ProjectNamePatterns.Count -gt 0
        $hasAgentPoolPatterns = $IncludeAgentPools -and $AgentPoolNamePatterns.Count -gt 0

        if(-not $hasProjectPatterns -and -not $hasAgentPoolPatterns) {
            Write-ToConsoleLog "No patterns provided for projects or agent pools. Nothing to do. Exiting..." -IsError
            return
        }

        # Discover resources to delete
        $projectsToDelete = @()
        $agentPoolsToDelete = @()

        # Discover projects
        if($hasProjectPatterns) {
            Write-ToConsoleLog "Discovering projects in organization: $organizationUrl"

            $allProjects = (az devops project list --org $organizationUrl -o json 2>$null) | ConvertFrom-Json
            if($null -eq $allProjects -or $null -eq $allProjects.value) {
                Write-ToConsoleLog "Failed to list projects in organization: $organizationUrl" -IsError
                return
            }

            $projectList = $allProjects.value
            Write-ToConsoleLog "Found $($projectList.Count) total projects in organization: $organizationUrl" -NoNewLine

            foreach($project in $projectList) {
                foreach($pattern in $ProjectNamePatterns) {
                    if($project.name -match $pattern) {
                        Write-ToConsoleLog "Project matches pattern '$pattern': $($project.name)" -NoNewLine
                        $projectsToDelete += @{
                            Name = $project.name
                            Id   = $project.id
                        }
                        break
                    }
                }
            }

            Write-ToConsoleLog "Found $($projectsToDelete.Count) projects matching patterns for deletion" -NoNewLine
        }

        # Discover agent pools
        if($hasAgentPoolPatterns) {
            Write-ToConsoleLog "Discovering agent pools in organization: $organizationUrl"

            $allAgentPools = (az pipelines pool list --org $organizationUrl -o json 2>$null) | ConvertFrom-Json
            if($null -eq $allAgentPools) {
                Write-ToConsoleLog "Failed to list agent pools in organization: $organizationUrl" -IsWarning
                $allAgentPools = @()
            }

            Write-ToConsoleLog "Found $($allAgentPools.Count) total agent pools in organization: $organizationUrl" -NoNewLine

            foreach($pool in $allAgentPools) {
                # Skip system pools (Azure Pipelines, Default, etc.)
                if($pool.isHosted -or $pool.poolType -eq "automation") {
                    Write-ToConsoleLog "Skipping hosted/system pool: $($pool.name)" -NoNewLine
                    continue
                }

                foreach($pattern in $AgentPoolNamePatterns) {
                    if($pool.name -match $pattern) {
                        Write-ToConsoleLog "Agent pool matches pattern '$pattern': $($pool.name)" -NoNewLine
                        $agentPoolsToDelete += @{
                            Name = $pool.name
                            Id   = $pool.id
                        }
                        break
                    }
                }
            }

            Write-ToConsoleLog "Found $($agentPoolsToDelete.Count) agent pools matching patterns for deletion" -NoNewLine
        }

        # Confirm deletion
        $totalResourcesToDelete = $projectsToDelete.Count + $agentPoolsToDelete.Count
        if($totalResourcesToDelete -eq 0) {
            Write-ToConsoleLog "No resources found matching the provided patterns. Nothing to delete." -IsWarning
            return
        }

        if(-not $BypassConfirmation) {
            Write-ToConsoleLog "The following Azure DevOps resources will be deleted:"

            if($projectsToDelete.Count -gt 0) {
                Write-ToConsoleLog "Projects ($($projectsToDelete.Count)):"
                $projectsToDelete | ForEach-Object { Write-ToConsoleLog "  - $($_.Name)" -NoNewLine }
            }

            if($agentPoolsToDelete.Count -gt 0) {
                Write-ToConsoleLog "Agent Pools ($($agentPoolsToDelete.Count)):"
                $agentPoolsToDelete | ForEach-Object { Write-ToConsoleLog "  - $($_.Name)" -NoNewLine }
            }

            if($PlanMode) {
                Write-ToConsoleLog "Skipping confirmation for plan mode"
            } else {
                $continue = Invoke-PromptForConfirmation -message "ALL LISTED AZURE DEVOPS RESOURCES WILL BE PERMANENTLY DELETED"
                if(-not $continue) {
                    Write-ToConsoleLog "Exiting..."
                    return
                }
            }
        }

        # Delete projects
        if($projectsToDelete.Count -gt 0) {
            Write-ToConsoleLog "Deleting projects..."

            $projectsToDelete | ForEach-Object -Parallel {
                $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                $TempLogFileForPlan = $using:TempLogFileForPlan
                $orgUrl = $using:organizationUrl

                $project = $_

                if($using:PlanMode) {
                    Write-ToConsoleLog `
                        "Would delete project: $($project.Name)", `
                        "Would run: az devops project delete --id $($project.Id) --org $orgUrl --yes" `
                        -IsPlan -LogFilePath $TempLogFileForPlan
                } else {
                    Write-ToConsoleLog "Deleting project: $($project.Name)" -NoNewLine
                    $result = az devops project delete --id $project.Id --org $orgUrl --yes 2>&1
                    if($LASTEXITCODE -ne 0) {
                        Write-ToConsoleLog "Failed to delete project: $($project.Name)", "Full error: $result" -IsWarning -NoNewLine
                    } else {
                        Write-ToConsoleLog "Deleted project: $($project.Name)" -NoNewLine
                    }
                }
            } -ThrottleLimit $ThrottleLimit
        }

        # Delete agent pools
        if($agentPoolsToDelete.Count -gt 0) {
            Write-ToConsoleLog "Deleting agent pools..."

            $agentPoolsToDelete | ForEach-Object -Parallel {
                $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                $TempLogFileForPlan = $using:TempLogFileForPlan
                $orgUrl = $using:organizationUrl

                $pool = $_

                if($using:PlanMode) {
                    Write-ToConsoleLog `
                        "Would delete agent pool: $($pool.Name)", `
                        "Would run: az pipelines pool delete --id $($pool.Id) --org $orgUrl --yes" `
                        -IsPlan -LogFilePath $TempLogFileForPlan
                } else {
                    Write-ToConsoleLog "Deleting agent pool: $($pool.Name)" -NoNewLine
                    $result = az pipelines pool delete --id $pool.Id --org $orgUrl --yes 2>&1
                    if($LASTEXITCODE -ne 0) {
                        Write-ToConsoleLog "Failed to delete agent pool: $($pool.Name)", "Full error: $result" -IsWarning -NoNewLine
                    } else {
                        Write-ToConsoleLog "Deleted agent pool: $($pool.Name)" -NoNewLine
                    }
                }
            } -ThrottleLimit $ThrottleLimit
        }

        Write-ToConsoleLog "Cleanup completed." -IsSuccess

        if($PlanMode) {
            Write-ToConsoleLog "Plan mode enabled, no changes were made." -IsWarning
            $planLogContents = Get-Content -Path $TempLogFileForPlan -Raw
            Write-ToConsoleLog "Plan mode log contents:", $planLogContents -Color Gray
            Remove-Item -Path $TempLogFileForPlan -Force
        }
    }
}
