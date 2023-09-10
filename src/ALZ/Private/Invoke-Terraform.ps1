function Invoke-Terraform {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $moduleFolderPath,

        [Parameter(Mandatory = $false)]
        [string] $tfvarsFileName
    )

    if ($PSCmdlet.ShouldProcess("Apply Terraform", "modify")) {
        terraform -chdir="$moduleFolderPath" init
        terraform -chdir="$moduleFolderPath" apply -var-file="$tfvarsFileName"
    }
}