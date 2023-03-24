function Edit-ALZConfigurationFilesInPlace {
    param(

        [Parameter(Mandatory = $false)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination = ".",

        [Parameter(Mandatory = $true)]
        [object] $configuration
    )

    $locations = @("config")
    $files = @()

    foreach ($location in $locations) {
        $bicepModules = Join-Path $alzEnvironmentDestination $location
        $files += @(Get-ChildItem -Path $bicepModules -Recurse -Filter *.parameters.*.json)
    }

    foreach ($file in $files) {
        $bicepConfiguration = Get-Content $file.FullName | ConvertFrom-Json -AsHashtable
        $modified = $false
        foreach ($configKey in $configuration.PsObject.Properties) {
            foreach ($target in $configKey.Value.Targets) {

                # Find the appropriate item which will be changed in the Bicep file.
                $propertyNames = $target.Name -split "\."
                $bicepConfig = $bicepConfiguration.parameters

                for ($index=0; $index -lt $propertyNames.Length - 1; $index++) {
                    if ($bicepConfig -is [array]) {
                        # If this is an array - use the property as an array index...
                        $arrayIndex = $propertyNames[$index]
                        if ($arrayIndex -match "\[[0-9]+\]") {
                            $arrayIndex = $arrayIndex -replace "\[|\]",""
                        }

                        $bicepConfig = $bicepConfig[$arrayIndex]
                    } elseif ($bicepConfig.ContainsKey($propertyNames[$index]) -eq $false) {
                        # This property doesn't exist at this level in the hierarchy,
                        #  this isn't the property we're looking for, stop looking.
                        $bicepConfig = $null
                        break
                    } else {
                        # We found the item, keep indexing into the object.
                        $bicepConfig = $bicepConfig[$propertyNames[$index]]
                    }
                }

                # If we're here, we've got the object at the bottom of the hierarchy - and we can modify values on it.
                if ($target.Destination -eq "Parameters" -and $null -ne $bicepConfig) {
                    if ($configKey.Value.Type -eq "Computed") {
                        if ($configKey.Value.Value -is [array]) {
                            $formattedValues = @()
                            foreach($formatString in $configKey.Value.Value) {
                                $formattedValues += Format-TokenizedConfigurationString -tokenizedString $formatString -configuration $configuration
                            }
                            $bicepConfig[$propertyNames[-1]] = $formattedValues
                        } else {
                            $bicepConfig[$propertyNames[-1]] = Format-TokenizedConfigurationString -tokenizedString $configKey.Value.Value -configuration $configuration
                        }
                    } else {
                        $bicepConfig[$propertyNames[-1]] = $configKey.Value.Value
                    }
                    $modified = $true
                }
            }
        }

        if ($true -eq $modified) {
            Write-InformationColored $file.FullName -ForegroundColor Yellow -InformationAction Continue
            $bicepConfiguration | ConvertTo-Json -Depth 10  | Out-File $file.FullName
        }
    }
}
