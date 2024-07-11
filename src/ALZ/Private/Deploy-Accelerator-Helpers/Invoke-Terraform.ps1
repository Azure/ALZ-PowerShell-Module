function Invoke-Terraform {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $moduleFolderPath,

        [Parameter(Mandatory = $false)]
        [string] $tfvarsFileName,

        [Parameter(Mandatory = $false)]
        [switch] $autoApprove,

        [Parameter(Mandatory = $false)]
        [switch] $destroy
    )

    if ($PSCmdlet.ShouldProcess("Apply Terraform", "modify")) {
        terraform -chdir="$moduleFolderPath" init
        $action = "apply"
        if($destroy) {
            $action = "destroy"
        }

        Write-InformationColored "Terraform init has completed, now running the $action..." -ForegroundColor Green -NewLineBefore -InformationAction Continue

        $planFileName = "tfplan"

        $command = "terraform"
        $arguments = @()
        $arguments += "-chdir=$moduleFolderPath"
        $arguments += "plan"
        $arguments += "-out=$planFileName"
        $arguments += "-input=false"
        $arguments += "-var-file=$tfvarsFileName"

        if ($destroy) {
            $arguments += "-destroy"
        }

        Write-InformationColored "Running Plan Command for $action : $command $arguments" -ForegroundColor Green -NewLineBefore -InformationAction Continue
        & $command $arguments

        if(!$autoApprove) {
            Write-InformationColored "Terraform plan has completed, please review the plan and confirm you wish to continue." -ForegroundColor Yellow -NewLineBefore -InformationAction Continue
            $choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Yes", "&No")
            $message = "Please confirm you wish to apply the plan."
            $title = "Confirm Terraform plan"
            $resultIndex = $host.ui.PromptForChoice($title, $message, $choices, 0)
            if($resultIndex -eq 1) {
                Write-InformationColored "You have chosen not to apply the plan. Exiting..." -ForegroundColor Red -NewLineBefore -InformationAction Continue
                exit 0
            }
        }

        $command = "terraform"
        $arguments = @()
        $arguments += "-chdir=$moduleFolderPath"
        $arguments += "apply"
        $arguments += "-auto-approve"
        $arguments += "-input=false"
        $arguments += "$planFileName"

        Write-InformationColored "Running Apply Command for $action : $command $arguments" -ForegroundColor Green -NewLineBefore -InformationAction Continue
        & $command $arguments

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
            $arguments += "-var-file=$tfvarsFileName"

            Write-InformationColored "Running Apply Command for $action : $command $arguments" -ForegroundColor Green -NewLineBefore -InformationAction Continue
            & $command $arguments
            $exitCode = $LASTEXITCODE
        }

        if($exitCode -ne 0) {
            Write-InformationColored "Terraform $action failed with exit code $exitCode after $maxAttempts attempts. Please review the error and try again or raise an issue." -ForegroundColor Red -NewLineBefore -InformationAction Continue
            exit $exitCode
        }
    }
}