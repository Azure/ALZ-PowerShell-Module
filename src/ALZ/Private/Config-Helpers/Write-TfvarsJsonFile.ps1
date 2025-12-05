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

        if (Test-Path $tfvarsFilePath) {
            Remove-Item -Path $tfvarsFilePath
        }

        $jsonObject = [ordered]@{}

        # Extract connectivity and overall tags for DNS fallback logic
        $connectivityTags = $null
        $overallTags = $null
        
        $connectivityTagsProperty = $configuration.PSObject.Properties | Where-Object { $_.Name -eq "connectivity_tags" }
        if ($null -ne $connectivityTagsProperty) {
            $connectivityTags = $connectivityTagsProperty.Value.Value
        }
        
        $tagsProperty = $configuration.PSObject.Properties | Where-Object { $_.Name -eq "tags" }
        if ($null -ne $tagsProperty) {
            $overallTags = $tagsProperty.Value.Value
        }

        foreach ($configurationProperty in $configuration.PSObject.Properties | Sort-Object Name) {
            if ($skipItems -contains $configurationProperty.Name) {
                Write-Verbose "Skipping configuration property: $($configurationProperty.Name)"
                continue
            }

            $configurationValue = $configurationProperty.Value.Value

            if ($null -ne $configurationValue -and $configurationValue.ToString() -eq "sourced-from-env") {
                Write-Verbose "Sourced from env var: $($configurationProperty.Name)"
                continue
            }

            if ($configurationProperty.Value.Validator -eq "configuration_file_path") {
                $configurationValue = [System.IO.Path]::GetFileName($configurationValue)
            }

            # Process virtual_hubs to sanitize DNS zone tags
            if ($configurationProperty.Name -eq "virtual_hubs" -and $null -ne $configurationValue) {
                Write-Verbose "Processing virtual_hubs configuration to apply DNS-safe tags"
                $configurationValue = Set-DnsSafeTagsForVirtualHubs -virtualHubs $configurationValue -connectivityTags $connectivityTags -overallTags $overallTags
            }

            Write-Verbose "Writing to tfvars.json - Configuration Property: $($configurationProperty.Name) - Configuration Value: $configurationValue"
            $jsonObject.Add("$($configurationProperty.Name)", $configurationValue)
        }

        $jsonString = ConvertTo-Json $jsonObject -Depth 100
        $jsonString | Out-File $tfvarsFilePath
    }
}
