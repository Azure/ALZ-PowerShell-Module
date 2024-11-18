function Write-TfvarsJsonFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $tfvarsFilePath,

        [Parameter(Mandatory = $false)]
        [PSObject] $configuration,

        [Parameter(Mandatory = $false)]
        [string[]] $skipItems = @()
    )

    if ($PSCmdlet.ShouldProcess("Download Terraform Tools", "modify")) {

        if(Test-Path $tfvarsFilePath) {
            Remove-Item -Path $tfvarsFilePath
        }

        $jsonObject = [ordered]@{}

        foreach($configurationProperty in $configuration.PSObject.Properties | Sort-Object Name) {
            if($skipItems -contains $configurationProperty.Name) {
                Write-Verbose "Skipping configuration property: $($configurationProperty.Name)"
                continue
            }
            
            $configurationValue = $configurationProperty.Value.Value

            if($null -ne $configurationValue -and $configurationValue.ToString() -eq "sourced-from-env") {
                Write-Verbose "Sourced from env var: $($configurationProperty.Name)"
                continue
            }

            if($configurationProperty.Value.Validator -eq "configuration_file_path") {
                $configurationValue = [System.IO.Path]::GetFileName($configurationValue)
            }

            Write-Verbose "Writing to tfvars.json - Configuration Property: $($configurationProperty.Name) - Configuration Value: $configurationValue"
            $jsonObject.Add("$($configurationProperty.Name)", $configurationValue)
        }

        $jsonString = ConvertTo-Json $jsonObject -Depth 100
        $jsonString | Out-File $tfvarsFilePath
    }
}
