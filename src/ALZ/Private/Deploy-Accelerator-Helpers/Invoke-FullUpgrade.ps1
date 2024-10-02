function Invoke-FullUpgrade {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $bootstrapRelease,

        [Parameter(Mandatory = $false)]
        [string] $bootstrapPath,

        [Parameter(Mandatory = $false)]
        [string] $bootstrapModuleFolder,

        [Parameter(Mandatory = $false)]
        [switch] $autoApprove
    )

    if ($PSCmdlet.ShouldProcess("Upgrade Release", "Operation")) {

        # Run upgrade for bootstrap state
        $bootstrapWasUpgraded = Invoke-Upgrade `
            -moduleType "bootstrap" `
            -targetDirectory $bootstrapPath `
            -targetFolder $bootstrapModuleFolder `
            -cacheFileName "terraform.tfstate" `
            -release $bootstrapRelease `
            -autoApprove:$autoApprove.IsPresent

        if($bootstrapWasUpgraded) {
            Write-InformationColored "AUTOMATIC UPGRADE: Upgrade complete. If any starter files have been updated, you will need to remove branch protection in order for the Terraform apply to succeed." -NewLineBefore -ForegroundColor Yellow -InformationAction Continue
        }
    }
}
