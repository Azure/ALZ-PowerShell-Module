function Write-JsonFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $jsonFilePath,

        [Parameter(Mandatory = $false)]
        [PSObject[]] $configurations,

        [Parameter(Mandatory = $false)]
        [switch] $all
    )

    if ($PSCmdlet.ShouldProcess("Download Terraform Tools", "modify")) {

        if (Test-Path $jsonFilePath) {
            Remove-Item -Path $jsonFilePath
        }

        $environmentVariables = [ordered]@{}

        foreach ($configuration in $configurations) {
            Write-Verbose "Processing configuration for JSON output to $($jsonFilePath)"
            foreach ($configKey in $configuration.PsObject.Properties | Sort-Object Name) {
                Write-Verbose "Processing configuration key $($configKey.Name) for $($jsonFilePath)"
                Write-Verbose "Configuration key value: $(ConvertTo-Json $configKey.Value -Depth 100)"
                if($configKey.Value.Sensitive) {
                    Write-Verbose "Obfuscating sensitive configuration $($configKey.Name) from JSON output"
                    $environmentVariables.$($configKey.Name) = "<sensitive>"
                    continue
                }
                if($all) {
                    $environmentVariables.$($configKey.Name) = $configKey.Value.Value
                    continue
                }
                foreach ($target in $configKey.Value.Targets) {
                    if ($target.Destination -eq "Environment") {
                        $environmentVariables.$($target.Name) = $configKey.Value.Value
                    }
                }
            }
        }

        $json = ConvertTo-Json -InputObject $environmentVariables -Depth 100
        $json | Out-File -FilePath $jsonFilePath
    }
}
