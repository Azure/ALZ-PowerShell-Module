function Remove-TerraformMetaFileSet {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$path,
        [Parameter(Mandatory = $false)]
        [array]$terraformFilesOrFoldersToRemove = $(
            "terraform.tfstate",
            "terraform.tfstate.backup",
            ".terraform",
            "terraform.tfvars",
            ".terraform.lock.hcl",
            "examples",
            "yaml.tf",
            ".alzlib"
        ),
        [Parameter(Mandatory = $false)]
        [switch]$writeVerboseLogs
    )

    if ($PSCmdlet.ShouldProcess("Remove files", "modify")) {
        if ($terraformFilesOrFoldersToRemove.Length -eq 0 ) {
            Write-Verbose "No folders or files specified, so not removing aything from $path"
            return
        }

        $filesAndFolders = Get-ChildItem -Path $path -Force

        foreach ($fileOrFolder in $filesAndFolders) {
            if ($terraformFilesOrFoldersToRemove -contains $fileOrFolder.Name) {
                if ($writeVerboseLogs) {
                    Write-Verbose "Exact Match - Removing: $($fileOrFolder.FullName)"
                }
                Remove-Item -Path $fileOrFolder.FullName -Force -Recurse | Out-Null
            }
        }
    }
}
