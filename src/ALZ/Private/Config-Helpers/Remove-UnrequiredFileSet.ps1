function Remove-UnrequiredFileSet {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$path,
        [Parameter(Mandatory = $false)]
        [array]$foldersOrFilesToRetain = @(),
        [Parameter(Mandatory = $false)]
        [array]$subFoldersOrFilesToRemove = @()
    )

    if($PSCmdlet.ShouldProcess("Remove files", "modify")) {
        if($foldersOrFilesToRetain.Length -eq 0 -and $subFoldersOrFilesToRemove.Length -eq 0) {
            Write-Verbose "No folders or files to retain specified, so not removing aything from $path"
            return
        }

        $files = Get-ChildItem -Path $path -File -Recurse -Force
        $filesToRetain = @()

        foreach ($file in $files) {
            $fileRelativePath = $file.FullName.Replace($path, "").Replace("\", "/").TrimStart("/")
            $folderRelativePath = $file.Directory.FullName.Replace($path, "").Replace("\", "/").TrimStart("/")
            foreach ($folderOrFileToRetain in $foldersOrFilesToRetain) {
                if ($fileRelativePath -like "$folderOrFileToRetain*") {
                    $skipFile = $false
                    foreach($subfolderOrFileToRemove in $subFoldersOrFilesToRemove) {
                        if ($file.Name -eq $subfolderOrFileToRemove -or $file.Directory.Name -eq $subfolderOrFileToRemove -or $fileRelativePath.EndsWith("/$subfolderOrFileToRemove") -or $folderRelativePath.EndsWith("/$subfolderOrFileToRemove")) {
                            $skipFile = $true
                        }
                    }

                    if(!$skipFile) {
                        Write-Verbose "Retaining: $fileRelativePath at $($file.FullName)"
                        $filesToRetain += $file.FullName
                    }
                }
            }
        }

        foreach($file in $files) {
            if($filesToRetain -notcontains $file.FullName) {
                Write-Verbose "Removing: $($file.FullName)"
                Remove-Item -Path $file.FullName -Force | Out-Null
            }
        }

        $folders = Get-ChildItem -Path $path -Directory -Recurse -Force
        foreach($folder in $folders) {
            if(Test-Path $folder.FullName) {
                $folderItems = Get-ChildItem -Path $folder.FullName -Recurse -File -Force
                if($folderItems.Count -eq 0) {
                    Write-Verbose "Removing empty folder: $($folder.FullName)"
                    Remove-Item -Path $folder.FullName -Force -Recurse | Out-Null
                }
            }
        }
    }
}