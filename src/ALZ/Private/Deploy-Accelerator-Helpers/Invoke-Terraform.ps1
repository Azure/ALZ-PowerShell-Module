function Invoke-Terraform {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $moduleFolderPath,

        [Parameter(Mandatory = $false)]
        [string] $tfvarsFileName = "",

        [Parameter(Mandatory = $false)]
        [switch] $autoApprove,

        [Parameter(Mandatory = $false)]
        [switch] $destroy,

        [Parameter(Mandatory = $false)]
        [string] $output = "",

        [Parameter(Mandatory = $false)]
        [string] $outputFilePath = "",

        [Parameter(Mandatory = $false)]
        [switch] $silent
    )

    if ($PSCmdlet.ShouldProcess("Apply Terraform", "modify")) {
        terraform -chdir="$moduleFolderPath" init
        $action = "apply"
        if($destroy) {
            $action = "destroy"
        }

        if(!$silent) {
            Write-InformationColored "Terraform init has completed, now running the $action..." -ForegroundColor Green -NewLineBefore -InformationAction Continue
        }

        $planFileName = "tfplan"

        # Start timer
        $StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
        $StopWatch.Start()

        $command = "terraform"
        $arguments = @()
        $arguments += "-chdir=$moduleFolderPath"
        $arguments += "plan"
        $arguments += "-out=$planFileName"
        $arguments += "-input=false"
        if($tfvarsFileName -ne "") {
            $arguments += "-var-file=$tfvarsFileName"
        }

        if ($destroy) {
            $arguments += "-destroy"
        }

        if(!$silent) {
            Write-InformationColored "Running Plan Command for $action : $command $arguments" -ForegroundColor Green -NewLineBefore -InformationAction Continue
            & $command $arguments
        } else {
            & $command $arguments | Write-Verbose
        }

        $exitCode = $LASTEXITCODE

        # Stop and display timer
        $StopWatch.Stop()
        if(!$silent) {
            Write-InformationColored "Time taken to complete Terraform plan:" -ForegroundColor Green -NewLineBefore -InformationAction Continue
        }
        $StopWatch.Elapsed | Format-Table

        if($exitCode -ne 0) {
            Write-InformationColored "Terraform plan for $action failed with exit code $exitCode. Please review the error and try again or raise an issue." -ForegroundColor Red -NewLineBefore -InformationAction Continue
            throw "Terraform plan failed with exit code $exitCode. Please review the error and try again or raise an issue."
        }

        if(!$autoApprove) {
            Write-InformationColored "Terraform plan has completed, please review the plan and confirm you wish to continue." -ForegroundColor Yellow -NewLineBefore -InformationAction Continue
            $choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Yes", "&No")
            $message = "Please confirm you wish to apply the plan."
            $title = "Confirm Terraform plan"
            $resultIndex = $host.ui.PromptForChoice($title, $message, $choices, 0)
            if($resultIndex -eq 1) {
                Write-InformationColored "You have chosen not to apply the plan. Exiting..." -ForegroundColor Red -NewLineBefore -InformationAction Continue
                return
            }
        }

        # Start timer
        $StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
        $StopWatch.Start()

        $command = "terraform"
        $arguments = @()
        $arguments += "-chdir=$moduleFolderPath"
        $arguments += "apply"
        $arguments += "-auto-approve"
        $arguments += "-input=false"
        $arguments += "$planFileName"

        if(!$silent) {
            Write-InformationColored "Running Apply Command for $action : $command $arguments" -ForegroundColor Green -NewLineBefore -InformationAction Continue
            & $command $arguments
        } else {
            & $command $arguments | Write-Verbose
        }

        $exitCode = $LASTEXITCODE

        $currentAttempt = 0
        $maxAttempts = 5

        while($exitCode -ne 0 -and $currentAttempt -lt $maxAttempts) {
            Write-InformationColored "Terraform $action failed with exit code $exitCode. This is likely a transient issue, so we are retrying..." -ForegroundColor Yellow -NewLineBefore -InformationAction Continue
            $currentAttempt++
            $command = "terraform"
            $arguments = @()
            $arguments += "-chdir=$moduleFolderPath"
            $arguments += "apply"
            $arguments += "-auto-approve"
            $arguments += "-input=false"
            if($tfvarsFileName -ne "") {
                $arguments += "-var-file=$tfvarsFileName"
            }
            if ($destroy) {
                $arguments += "-destroy"
            }

            Write-InformationColored "Running Apply Command for $action : $command $arguments" -ForegroundColor Green -NewLineBefore -InformationAction Continue
            & $command $arguments
            $exitCode = $LASTEXITCODE
        }

        # Stop and display timer
        $StopWatch.Stop()
        if(!$silent) {
            Write-InformationColored "Time taken to complete Terraform apply:" -ForegroundColor Green -NewLineBefore -InformationAction Continue
        }
        $StopWatch.Elapsed | Format-Table

        if($exitCode -ne 0) {
            Write-InformationColored "Terraform $action failed with exit code $exitCode after $maxAttempts attempts. Please review the error and try again or raise an issue." -ForegroundColor Red -NewLineBefore -InformationAction Continue
            throw "Terraform $action failed with exit code $exitCode after $maxAttempts attempts. Please review the error and try again or raise an issue."
        } else {
            if($output -ne "") {
                if($outputFilePath -eq "") {
                    $outputFilePath = Join-Path $moduleFolderPath "output.json"
                }
                $command = "terraform"
                $arguments = @()
                $arguments += "-chdir=$moduleFolderPath"
                $arguments += "output"
                $arguments += "-json"
                $arguments += "$output"

                Write-Verbose "Outputting $output to $outputFilePath"
                Write-Verbose "Running Output Command: $command $arguments"
                & $command $arguments > $outputFilePath
            }
        }
    }
}