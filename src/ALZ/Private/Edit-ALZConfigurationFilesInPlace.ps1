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
                # Remove array '[' ']' characters so we can use the index value direct.
                $propertyNames = $target.Name -replace "\[|\]","" -split "\."
                $bicepConfigNode = $bicepConfiguration.parameters
                $index = 0

                # Keep navigating into properties which the configuration specifies until we reach the bottom most object,
                #  e.g. not a value type - but the object reference so the value is persisted.
                do {
                    if ($bicepConfigNode -is [array]) {
                        # If this is an array - use the property as an array index...
                        if ($propertyNames[$index] -match "[0-9]+" -eq $false) {
                            throw "Configuration specifies an array, but the index value '${$propertyNames[$index]}' is not a number"
                        }

                        $bicepConfigNode = $bicepConfigNode[$propertyNames[$index]]

                    } elseif ($bicepConfigNode.ContainsKey($propertyNames[$index]) -eq $true) {
                        # We found the item, keep indexing into the object.
                        $bicepConfigNode = $bicepConfigNode[$propertyNames[$index]]
                    } else {
                        # This property doesn't exist at this level in the hierarchy,
                        #  this isn't the property we're looking for, stop looking.
                        $bicepConfigNode = $null
                    }

                    ++$index

                } while (($null -ne $bicepConfigNode) -and ($index -lt $propertyNames.Length - 1))

                # If we're here, we've got the object at the bottom of the hierarchy - and we can modify values on it.
                if ($target.Destination -eq "Parameters" -and $null -ne $bicepConfigNode) {
                    $leafPropertyName = $propertyNames[-1]

                    if ($configKey.Value.Type -eq "Computed") {
                        # If the value type is computed we replace the value with another which already exists in the configuration hierarchy.
                        if ($configKey.Value.Value -is [array]) {
                            $formattedValues = @()
                            foreach($formatString in $configKey.Value.Value) {
                                $formattedValues += Format-TokenizedConfigurationString -tokenizedString $formatString -configuration $configuration
                            }

                            if ($null -ne $configKey.Value.Process) {
                                $scriptBlock = [ScriptBlock]::Create($configKey.Value.Process)
                                $formattedValues = Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $formattedValues
                                $formattedValues = @( $formattedValues)
                            }

                            $bicepConfigNode[$leafPropertyName] = $formattedValues
                        } else {

                            $formattedValue = Format-TokenizedConfigurationString -tokenizedString $configKey.Value.Value -configuration $configuration

                            if ($null -ne $configKey.Value.Process) {
                                $scriptBlock = [ScriptBlock]::Create($configKey.Value.Process)
                                $formattedValue = Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $formattedValue
                            }

                            $bicepConfigNode[$leafPropertyName] = $formattedValue
                        }
                    } else {
                        $bicepConfigNode[$leafPropertyName] = $configKey.Value.Value
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
