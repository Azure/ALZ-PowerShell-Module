function Write-TfvarsFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $tfvarsFilePath,

        [Parameter(Mandatory = $false)]
        [PSObject] $configuration
    )

    if ($PSCmdlet.ShouldProcess("Download Terraform Tools", "modify")) {

        if(Test-Path $tfvarsFilePath) {
            Remove-Item -Path $tfvarsFilePath
        }

        foreach($configurationProperty in $configuration.PSObject.Properties) {
            $configurationValueRaw = $configurationProperty.Value.Value

            if($configurationProperty.Value.Validator -eq "configuration_file_path") {
                $configurationValueRaw = [System.IO.Path]::GetFileName($configurationValueRaw)
            }

            $configurationValue = "`"$($configurationValueRaw)`""

            if($configurationProperty.Value.DataType -eq "list(string)") {
                if($configurationValueRaw -eq "") {
                    $configurationValue = "[]"
                } else {
                    $split = $configurationValueRaw -split ","
                    $join = $split -join "`",`""
                    $configurationValue = "[`"$join`"]"
                }
            }

            if($configurationProperty.Value.DataType -eq "number" -or $configurationProperty.Value.DataType -eq "bool") {
                $configurationValue = $configurationValueRaw
            } else {
                $configurationValue = $configurationValue.Replace("\", "\\")
            }

            Add-Content -Path $tfvarsFilePath -Value "$($configurationProperty.Name) = $($configurationValue)"
        }

        $tfvarsFolderPath = Split-Path -Path $tfvarsFilePath -Parent

        terraform -chdir="$tfvarsFolderPath" fmt | Out-String | Write-Verbose
    }
}