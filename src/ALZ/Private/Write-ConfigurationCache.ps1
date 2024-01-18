function Write-ConfigurationCache {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $filePath,

        [Parameter(Mandatory = $false)]
        [PSObject] $configuration
    )

    if ($PSCmdlet.ShouldProcess("Download Terraform Tools", "modify")) {

        if(Test-Path $filePath) {
            Remove-Item -Path $filePath
        }

        $cache = [PSCustomObject]@{}
        foreach ($configurationItem in $configuration.PSObject.Properties) {
            if($configurationItem.Value.Type -eq "ComputedInput") {
                continue
            }
            $cache | Add-Member -NotePropertyName $configurationItem.Name -NotePropertyValue $configurationItem.Value.Value
        }

        $cache | ConvertTo-Json | Out-File -FilePath $filePath
    }
}