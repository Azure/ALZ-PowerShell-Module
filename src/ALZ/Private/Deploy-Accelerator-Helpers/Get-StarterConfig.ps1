
function Get-StarterConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$starterPath,
        [Parameter(Mandatory = $false)]
        [string]$starterConfigPath
    )

    if ($PSCmdlet.ShouldProcess("Get Configuration for Bootstrap and Starter", "modify")) {
        # Get the bootstap configuration
        $starterConfigFullPath = Join-Path $starterPath $starterConfigPath
        Write-Verbose "Starter config path $starterConfigFullPath"
        $starterConfig = Get-ALZConfig -configFilePath $starterConfigFullPath

        return $starterConfig
    }
}
