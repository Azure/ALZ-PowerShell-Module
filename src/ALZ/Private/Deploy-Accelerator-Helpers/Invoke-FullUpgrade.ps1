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
        [string] $starterRelease,

        [Parameter(Mandatory = $false)]
        [string] $starterPath,

        [Parameter(Mandatory = $false)]
        [string] $interfaceCacheFileName,

        [Parameter(Mandatory = $false)]
        [string] $bootstrapCacheFileName,

        [Parameter(Mandatory = $false)]
        [string] $starterCacheFileName,

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
            # Run upgrade for interface inputs
            Invoke-Upgrade `
                -targetDirectory $bootstrapPath `
                -cacheFileName $interfaceCacheFileName `
                -release $bootstrapRelease `
                -autoApprove:$bootstrapWasUpgraded | Out-String | Write-Verbose

            # Run upgrade for bootstrap inputs
            Invoke-Upgrade `
                -targetDirectory $bootstrapPath `
                -cacheFileName $bootstrapCacheFileName `
                -release $bootstrapRelease `
                -autoApprove:$bootstrapWasUpgraded | Out-String | Write-Verbose
        }

        # Run upgrade for starter
        $starterWasUpgraded = Invoke-Upgrade `
            -moduleType "starter" `
            -targetDirectory $starterPath `
            -cacheFileName $starterCacheFileName `
            -release $starterRelease `
            -autoApprove:$autoApprove.IsPresent | Out-String | Write-Verbose

        if($starterWasUpgraded -or $bootstrapWasUpgraded) {
            Write-InformationColored "AUTOMATIC UPGRADE: Upgrade complete. If any starter files have been updated, you will need to remove branch protection in order for the Terraform apply to succeed." -NewLineBefore -ForegroundColor Yellow -InformationAction Continue
        }
    }
}
