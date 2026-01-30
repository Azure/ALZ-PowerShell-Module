function Remove-GitHubAccelerator {
    <#
    .SYNOPSIS
        Removes GitHub resources created by the Azure Landing Zone accelerator bootstrap modules.

    .DESCRIPTION
        The Remove-GitHubAccelerator function performs cleanup of GitHub resources that were created by the
        Azure Landing Zone accelerator bootstrap process (https://github.com/Azure/accelerator-bootstrap-modules).
        This includes repositories, teams, and optionally runner groups.

        The function operates in the following sequence:
        1. Validates GitHub CLI authentication
        2. Prompts for confirmation (unless bypassed or in plan mode)
        3. Discovers and deletes repositories matching the specified patterns
        4. Discovers and deletes teams matching the specified patterns
        5. Optionally discovers and deletes runner groups matching the specified patterns

        CRITICAL WARNING: This is a highly destructive operation that will permanently delete GitHub resources.
        Use with extreme caution and ensure you have appropriate backups and authorization before executing.

    .PARAMETER GitHubOrganization
        The GitHub organization name where the resources to be deleted are located.
        This parameter is required.

    .PARAMETER RepositoryNamePatterns
        An array of regex patterns to match against repository names. Repositories matching any of these
        patterns will be deleted. If empty, no repositories will be deleted.
        Default: Empty array (no repositories deleted)

    .PARAMETER TeamNamePatterns
        An array of regex patterns to match against team names. Teams matching any of these patterns
        will be deleted. If empty, no teams will be deleted.
        Default: Empty array (no teams deleted)

    .PARAMETER RunnerGroupNamePatterns
        An array of regex patterns to match against runner group names. Runner groups matching any of
        these patterns will be deleted. If empty, no runner groups will be deleted.
        Default: Empty array (no runner groups deleted)

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
        Remove-GitHubAccelerator -GitHubOrganization "my-org" -RepositoryNamePatterns @("^alz-.*") -PlanMode

        Shows what repositories matching the pattern "^alz-.*" would be deleted from the "my-org"
        organization without making any changes.

    .EXAMPLE
        Remove-GitHubAccelerator -GitHubOrganization "my-org" -RepositoryNamePatterns @("^alz-.*") -TeamNamePatterns @("^alz-.*")

        Deletes all repositories and teams matching the pattern "^alz-.*" from the "my-org" organization.

    .EXAMPLE
        Remove-GitHubAccelerator -GitHubOrganization "my-org" -RepositoryNamePatterns @("^alz-.*", "^landing-zone-.*") -RunnerGroupNamePatterns @("^alz-.*")

        Deletes repositories matching either pattern and runner groups matching "^alz-.*" from the
        "my-org" organization.

    .EXAMPLE
        Remove-GitHubAccelerator -GitHubOrganization "my-org" -RepositoryNamePatterns @("^test-alz$") -BypassConfirmation -BypassConfirmationTimeoutSeconds 10

        Deletes the repository named exactly "test-alz" with a 10-second confirmation bypass timeout.

    .NOTES
        This function requires the GitHub CLI (gh) to be installed and authenticated.
        Install GitHub CLI: https://cli.github.com/
        Authenticate: gh auth login

        Required permissions:
        - delete:repo (to delete repositories)
        - admin:org (to delete teams and runner groups)
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "[REQUIRED] The GitHub organization name.")]
        [Alias("org")]
        [string]$GitHubOrganization,

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Regex patterns to match repository names for deletion.")]
        [Alias("repos")]
        [string[]]$RepositoryNamePatterns = @(),

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Regex patterns to match team names for deletion.")]
        [Alias("teams")]
        [string[]]$TeamNamePatterns = @(),

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Regex patterns to match runner group names for deletion.")]
        [Alias("runners")]
        [string[]]$RunnerGroupNamePatterns = @(),

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Bypass interactive confirmation prompts.")]
        [switch]$BypassConfirmation,

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Seconds to wait when bypassing confirmation.")]
        [int]$BypassConfirmationTimeoutSeconds = 30,

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Maximum parallel operations.")]
        [int]$ThrottleLimit = 11,

        [Parameter(Mandatory = $false, HelpMessage = "[OPTIONAL] Enable dry run mode - no changes will be made.")]
        [switch]$PlanMode
    )

    # Main execution starts here
    if ($PSCmdlet.ShouldProcess("Delete GitHub Resources", "delete")) {

        Test-Tooling -Checks @("GitHubCli")

        $TempLogFileForPlan = ""
        if($PlanMode) {
            Write-ToConsoleLog "Plan Mode enabled, no changes will be made. All actions will be logged as what would be performed." -IsWarning
            $TempLogFileForPlan = (New-TemporaryFile).FullName
        }

        $funcWriteToConsoleLog = ${function:Write-ToConsoleLog}.ToString()

        if($BypassConfirmation) {
            Write-ToConsoleLog "Bypass confirmation enabled, proceeding without prompts..." -IsWarning
            Write-ToConsoleLog "This is a highly destructive operation that will permanently delete GitHub resources!" -IsWarning
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

        $hasRepositoryPatterns = $RepositoryNamePatterns.Count -gt 0
        $hasTeamPatterns = $TeamNamePatterns.Count -gt 0
        $hasRunnerGroupPatterns = $RunnerGroupNamePatterns.Count -gt 0

        if(-not $hasRepositoryPatterns -and -not $hasTeamPatterns -and -not $hasRunnerGroupPatterns) {
            Write-ToConsoleLog "No patterns provided for repositories, teams, or runner groups. Nothing to do. Exiting..." -IsError
            return
        }

        # Discover resources to delete
        $repositoriesToDelete = @()
        $teamsToDelete = @()
        $runnerGroupsToDelete = @()

        # Discover repositories
        if($hasRepositoryPatterns) {
            Write-ToConsoleLog "Discovering repositories in organization: $GitHubOrganization"

            $allRepositories = (gh repo list $GitHubOrganization --json name,url --limit 1000) | ConvertFrom-Json
            if($null -eq $allRepositories) {
                Write-ToConsoleLog "Failed to list repositories in organization: $GitHubOrganization" -IsError
                return
            }

            Write-ToConsoleLog "Found $($allRepositories.Count) total repositories in organization: $GitHubOrganization"

            foreach($repo in $allRepositories) {
                foreach($pattern in $RepositoryNamePatterns) {
                    if($repo.name -match $pattern) {
                        Write-ToConsoleLog "Repository matches pattern '$pattern': $($repo.name)"
                        $repositoriesToDelete += @{
                            Name = $repo.name
                            Url  = $repo.url
                        }
                        break
                    }
                }
            }

            Write-ToConsoleLog "Found $($repositoriesToDelete.Count) repositories matching patterns for deletion"
        }

        # Discover teams
        if($hasTeamPatterns) {
            Write-ToConsoleLog "Discovering teams in organization: $GitHubOrganization"

            $allTeams = (gh api "orgs/$GitHubOrganization/teams" --paginate) | ConvertFrom-Json
            if($null -eq $allTeams) {
                Write-ToConsoleLog "Failed to list teams in organization: $GitHubOrganization" -IsWarning
                $allTeams = @()
            }

            Write-ToConsoleLog "Found $($allTeams.Count) total teams in organization: $GitHubOrganization"

            foreach($team in $allTeams) {
                foreach($pattern in $TeamNamePatterns) {
                    if($team.name -match $pattern -or $team.slug -match $pattern) {
                        Write-ToConsoleLog "Team matches pattern '$pattern': $($team.name) (slug: $($team.slug))"
                        $teamsToDelete += @{
                            Name = $team.name
                            Slug = $team.slug
                            Id   = $team.id
                        }
                        break
                    }
                }
            }

            Write-ToConsoleLog "Found $($teamsToDelete.Count) teams matching patterns for deletion"
        }

        # Discover runner groups
        if($hasRunnerGroupPatterns) {
            Write-ToConsoleLog "Discovering runner groups in organization: $GitHubOrganization"

            $runnerGroupsResponse = (gh api "orgs/$GitHubOrganization/actions/runner-groups" --paginate 2>&1)
            if($LASTEXITCODE -ne 0) {
                Write-ToConsoleLog "Failed to list runner groups in organization: $GitHubOrganization (may require GitHub Enterprise)" -IsWarning
                $allRunnerGroups = @()
            } else {
                $allRunnerGroups = ($runnerGroupsResponse | ConvertFrom-Json).runner_groups
            }

            if($null -ne $allRunnerGroups) {
                Write-ToConsoleLog "Found $($allRunnerGroups.Count) total runner groups in organization: $GitHubOrganization"

                foreach($runnerGroup in $allRunnerGroups) {
                    # Skip the default runner group as it cannot be deleted
                    if($runnerGroup.name -eq "Default" -or $runnerGroup.default) {
                        Write-ToConsoleLog "Skipping default runner group: $($runnerGroup.name)"
                        continue
                    }

                    foreach($pattern in $RunnerGroupNamePatterns) {
                        if($runnerGroup.name -match $pattern) {
                            Write-ToConsoleLog "Runner group matches pattern '$pattern': $($runnerGroup.name)"
                            $runnerGroupsToDelete += @{
                                Name = $runnerGroup.name
                                Id   = $runnerGroup.id
                            }
                            break
                        }
                    }
                }

                Write-ToConsoleLog "Found $($runnerGroupsToDelete.Count) runner groups matching patterns for deletion"
            }
        }

        # Confirm deletion
        $totalResourcesToDelete = $repositoriesToDelete.Count + $teamsToDelete.Count + $runnerGroupsToDelete.Count
        if($totalResourcesToDelete -eq 0) {
            Write-ToConsoleLog "No resources found matching the provided patterns. Nothing to delete." -IsWarning
            return
        }

        if(-not $BypassConfirmation) {
            Write-ToConsoleLog "The following GitHub resources will be deleted:"

            if($repositoriesToDelete.Count -gt 0) {
                Write-ToConsoleLog "Repositories ($($repositoriesToDelete.Count)):"
                $repositoriesToDelete | ForEach-Object { Write-ToConsoleLog "  - $($_.Name)"  }
            }

            if($teamsToDelete.Count -gt 0) {
                Write-ToConsoleLog "Teams ($($teamsToDelete.Count)):"
                $teamsToDelete | ForEach-Object { Write-ToConsoleLog "  - $($_.Name) (slug: $($_.Slug))"  }
            }

            if($runnerGroupsToDelete.Count -gt 0) {
                Write-ToConsoleLog "Runner Groups ($($runnerGroupsToDelete.Count)):"
                $runnerGroupsToDelete | ForEach-Object { Write-ToConsoleLog "  - $($_.Name)"  }
            }

            if($PlanMode) {
                Write-ToConsoleLog "Skipping confirmation for plan mode"
            } else {
                $continue = Invoke-PromptForConfirmation -message "ALL LISTED GITHUB RESOURCES WILL BE PERMANENTLY DELETED"
                if(-not $continue) {
                    Write-ToConsoleLog "Exiting..."
                    return
                }
            }
        }

        # Delete repositories
        if($repositoriesToDelete.Count -gt 0) {
            Write-ToConsoleLog "Deleting repositories..."

            $repositoriesToDelete | ForEach-Object -Parallel {
                $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                $TempLogFileForPlan = $using:TempLogFileForPlan
                $org = $using:GitHubOrganization

                $repo = $_
                $repoFullName = "$org/$($repo.Name)"

                if($using:PlanMode) {
                    Write-ToConsoleLog `
                        "Would delete repository: $repoFullName", `
                        "Would run: gh repo delete $repoFullName --yes" `
                        -IsPlan -LogFilePath $TempLogFileForPlan
                } else {
                    Write-ToConsoleLog "Deleting repository: $repoFullName"
                    $result = gh repo delete $repoFullName --yes 2>&1
                    if($LASTEXITCODE -ne 0) {
                        Write-ToConsoleLog "Failed to delete repository: $repoFullName", "Full error: $result" -IsWarning
                    } else {
                        Write-ToConsoleLog "Deleted repository: $repoFullName"
                    }
                }
            } -ThrottleLimit $ThrottleLimit
        }

        # Delete teams
        if($teamsToDelete.Count -gt 0) {
            Write-ToConsoleLog "Deleting teams..."

            $teamsToDelete | ForEach-Object -Parallel {
                $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                $TempLogFileForPlan = $using:TempLogFileForPlan
                $org = $using:GitHubOrganization

                $team = $_

                if($using:PlanMode) {
                    Write-ToConsoleLog `
                        "Would delete team: $($team.Name) (slug: $($team.Slug))", `
                        "Would run: gh api -X DELETE orgs/$org/teams/$($team.Slug)" `
                        -IsPlan -LogFilePath $TempLogFileForPlan
                } else {
                    Write-ToConsoleLog "Deleting team: $($team.Name) (slug: $($team.Slug))"
                    $result = gh api -X DELETE "orgs/$org/teams/$($team.Slug)" 2>&1
                    if($LASTEXITCODE -ne 0) {
                        Write-ToConsoleLog "Failed to delete team: $($team.Name)", "Full error: $result" -IsWarning
                    } else {
                        Write-ToConsoleLog "Deleted team: $($team.Name)"
                    }
                }
            } -ThrottleLimit $ThrottleLimit
        }

        # Delete runner groups
        if($runnerGroupsToDelete.Count -gt 0) {
            Write-ToConsoleLog "Deleting runner groups..."

            $runnerGroupsToDelete | ForEach-Object -Parallel {
                $funcWriteToConsoleLog = $using:funcWriteToConsoleLog
                ${function:Write-ToConsoleLog} = $funcWriteToConsoleLog
                $TempLogFileForPlan = $using:TempLogFileForPlan
                $org = $using:GitHubOrganization

                $runnerGroup = $_

                if($using:PlanMode) {
                    Write-ToConsoleLog `
                        "Would delete runner group: $($runnerGroup.Name)", `
                        "Would run: gh api -X DELETE orgs/$org/actions/runner-groups/$($runnerGroup.Id)" `
                        -IsPlan -LogFilePath $TempLogFileForPlan
                } else {
                    Write-ToConsoleLog "Deleting runner group: $($runnerGroup.Name)"
                    $result = gh api -X DELETE "orgs/$org/actions/runner-groups/$($runnerGroup.Id)" 2>&1
                    if($LASTEXITCODE -ne 0) {
                        Write-ToConsoleLog "Failed to delete runner group: $($runnerGroup.Name)", "Full error: $result" -IsWarning
                    } else {
                        Write-ToConsoleLog "Deleted runner group: $($runnerGroup.Name)"
                    }
                }
            } -ThrottleLimit $ThrottleLimit
        }

        Write-ToConsoleLog "Cleanup completed." -IsSuccess

        if($PlanMode) {
            Write-ToConsoleLog "Plan mode enabled, no changes were made." -IsWarning
            $planLogContents = Get-Content -Path $TempLogFileForPlan -Raw
            Write-ToConsoleLog @("Plan mode log contents:", $planLogContents) -Color Gray
            Remove-Item -Path $TempLogFileForPlan -Force
        }
    }
}
