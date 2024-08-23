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

            if ($configurationProperty.Value.DataType -eq "list(string)") {
                if ($configurationValueRaw -eq "") {
                    $configurationValue = "[]"
                } else {
                    $split = $configurationValueRaw -split ","
                    $join = $split -join "`",`""
                    $configurationValue = "[`"$join`"]"
                }
                Write-Host "list(string) - Raw Value: $configurationValueRaw"
            }

            if ($configurationProperty.Value.DataType -eq "map(string)") {
                if (-not $configurationValueRaw -or $configurationValueRaw.Count -eq 0) {
                    $configurationValue = "{}"
                } else {
                    $configurationValue = "{"
                    $entries = @()

                    foreach ($key in $configurationValueRaw.Keys) {
                        $value = $configurationValueRaw[$key]
                        $entries += "`"$key`": `"$value`""
                    }

                    $configurationValue = $entries -join ", "
                    $configurationValue = "{ $configurationValue }"
                }
                Write-Host "map(string) - Processed Value: $configurationValue"
            }

            if ($configurationProperty.Value.DataType -eq "list(object)") {
                if ($configurationValueRaw -eq "") {
                    $configurationValue = "[]"
                } elseif ($configurationValueRaw -eq "[]") {
                    $configurationValue = "[]"
                } else {
                    $configurationValue = "["
                    foreach ($entry in $configurationValueRaw) {
                        $configurationValue += "{ "
                        foreach ($keyValue in $entry.PSObject.Properties) {
                            $key = $keyValue.Name
                            $value = $keyValue.Value
                            $configurationValue += "`"$key`": `"$value`", "
                        }
                        $configurationValue = $configurationValue.TrimEnd(", ")
                        $configurationValue += "}, "
                    }
                    $configurationValue = $configurationValue.TrimEnd(", ")
                    $configurationValue += "]"
                }
                Write-Host "list(object) - Raw Value: $configurationValueRaw"
                Write-Host "list(object) - Processed Value: $configurationValue"
            }


            if ($configurationProperty.Value.DataType -eq "number" -or $configurationProperty.Value.DataType -eq "bool") {
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
