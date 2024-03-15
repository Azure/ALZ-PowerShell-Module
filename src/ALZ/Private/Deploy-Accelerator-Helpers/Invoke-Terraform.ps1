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

        Write-InformationColored "Terraform init has completed, now running the $action..." -ForegroundColor Green -InformationAction Continue

        if($destroy) {
            if($autoApprove) {
                terraform -chdir="$moduleFolderPath" destroy -var-file="$tfvarsFileName" -auto-approve
            } else {
                terraform -chdir="$moduleFolderPath" destroy -var-file="$tfvarsFileName"
            }
        } else {
            if($autoApprove) {
                terraform -chdir="$moduleFolderPath" apply -var-file="$tfvarsFileName" -auto-approve
            } else {
                terraform -chdir="$moduleFolderPath" apply -var-file="$tfvarsFileName"
            }
        }
    }
}