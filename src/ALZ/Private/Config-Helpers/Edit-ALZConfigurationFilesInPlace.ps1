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
        Write-Verbose "Checking Bicep parameter file: $($file.Name)"
        $bicepConfiguration = Get-Content $file.FullName | ConvertFrom-Json -AsHashtable
        $modified = $false

        foreach ($configKey in $configuration.PsObject.Properties) {
            foreach ($target in $configKey.Value.Targets) {
                # Is this configuration value for this file?
                $targetedAtThisFile = $target.Destination -eq "Parameters" -and ($null -eq $target.File -or $target.File -eq $file.Name)
                if ($targetedAtThisFile -eq $false) {
                    continue
                }

                Write-Verbose "Attempting to update $($target.Name) in $($file.Name) with '$($configKey.Value.Value)' from $($configKey.Name)"

                # Find the appropriate item which will be changed in the Bicep file.
                # Remove array '[' ']' characters so we can use the index value direct.
                $propertyNames = $target.Name.Replace("[", ".").Replace("]", "").Replace("..", ".") -split "\."
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

                # If we're here, we can modify this file and we've got an actual object specified by the Name path value - and we can modify values on it.
                if ($target.Destination -eq "Parameters" -and $null -ne $bicepConfigNode) {
                    $leafPropertyName = $propertyNames[-1]
                    Write-Verbose "Updating $($target.Name) in $($file.Name) with '$($configKey.Value.Value)' from $($configKey.Name)"
                    $bicepConfigNode[$leafPropertyName] = $configKey.Value.Value
                    $modified = $true
                }
            }
        }

        if ($true -eq $modified) {
            Write-Verbose "Updating Bicep parameter file: $($file.Name)"
            ConvertTo-Json $bicepConfiguration -Depth 10 | Out-File $file.FullName
        }
    }
}
