function Invoke-Terraform {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $moduleFolderPath,

        [Parameter(Mandatory = $false)]
        [string] $tfvarsFileName,

        [Parameter(Mandatory = $false)]
        [switch] $autoApprove
    )

    if ($PSCmdlet.ShouldProcess("Apply Terraform", "modify")) {
        terraform -chdir="$moduleFolderPath" init
        Write-InformationColored "Terraform init has completed, now running the apply..." -ForegroundColor Green -InformationAction Continue
        if($autoApprove) {
            terraform -chdir="$moduleFolderPath" apply -var-file="$tfvarsFileName" -auto-approve
        } else {
            terraform -chdir="$moduleFolderPath" apply -var-file="$tfvarsFileName"
        }
    }
}