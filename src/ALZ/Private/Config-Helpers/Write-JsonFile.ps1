function Write-JsonFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $jsonFilePath,

        [Parameter(Mandatory = $false)]
        [PSObject] $configuration
    )

    if ($PSCmdlet.ShouldProcess("Download Terraform Tools", "modify")) {

        if(Test-Path $jsonFilePath) {
            Remove-Item -Path $jsonFilePath
        }

        $environmentVariables = @{}

        foreach ($configKey in $configuration.PsObject.Properties) {
            foreach ($target in $configKey.Value.Targets) {
                if($target.Destination -eq "Environment" -and $target.Required) {
                    $environmentVariables.$($target.Name) = $configKey.Value.Value
                }
            }
        }

        $json = ConvertTo-Json -InputObject $environmentVariables -Depth 10
        $json | Out-File -FilePath $jsonFilePath
    }
}