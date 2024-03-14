
function New-ModuleSetup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$targetDirectory,
        [Parameter(Mandatory = $false)]
        [string]$targetFolder,
        [Parameter(Mandatory = $false)]
        [string]$sourceFolder,
        [Parameter(Mandatory = $false)]
        [string]$url,
        [Parameter(Mandatory = $false)]
        [string]$release,
        [Parameter(Mandatory = $false)]
        [string]$moduleOverrideFolderPath,
        [Parameter(Mandatory = $false)]
        [bool]$skipInternetChecks
    )

    if ($PSCmdlet.ShouldProcess("Check and get module", "modify")) {
        $versionAndPath = $null

        if($skipInternetChecks) {
            $versionAndPath = Get-ExistingLocalRelease -targetDirectory $targetDirectory -targetFolder $targetFolder
        } else {
            $versionAndPath = New-FolderStructure `
                -targetDirectory $targetDirectory `
                -url $url `
                -release $release `
                -targetFolder $targetFolder `
                -sourceFolder $sourceFolder `
                -overrideSourceDirectoryPath $moduleOverrideFolderPath
        }
        return $versionAndPath
    }
}
