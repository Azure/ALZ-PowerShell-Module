function Remove-FilesNotRequired {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$path,

        [Parameter(Mandatory = $false)]
        [array]$foldersToKeep = @("accelerator", "infra-as-code", "config"),

        [Parameter(Mandatory = $false)]
        [array]$filesToKeep = @("version.json", "parameters.json", "starter-cache.json"),

        [Parameter(Mandatory = $false)]
        [array]$foldersToRemove = @("media", "samples", "generateddocs")
    )

    if ($PSCmdlet.ShouldProcess("Remove files", "modify")) {
        $folders = Get-ChildItem -Path $path -Directory
        foreach ($folder in $folders) {
            if ($foldersToKeep -notcontains $folder.Name) {
                Write-Verbose "Removing folder: $($folder.FullName)"
                Remove-Item -Path $folder.FullName -Recurse -Force | Out-String | Write-Verbose
            }
        }

        $files = Get-ChildItem -Path $path -File
        foreach ($file in $files) {
            if ($filesToKeep -notcontains $file.Name) {
                Write-Verbose "Removing folder: $($file.FullName)"
                Remove-Item -Path $file.FullName -Force | Out-String | Write-Verbose
            }
        }

        $subFolders = Get-ChildItem -Path $path -Directory -Recurse
        foreach ($subFolder in $subFolders) {
            if ($foldersToRemove -contains $subFolder.Name) {
                if(Test-Path $subFolder.FullName) {
                    Write-Verbose "Removing folder: $($subFolder.FullName)"
                    Remove-Item -Path $subFolder.FullName -Recurse -Force | Out-String | Write-Verbose
                }
            }
        }
    }
}