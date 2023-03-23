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

    $locations = @("orchestration", "config", "customization")
    $files = @()

    foreach ($location in $locations) {
        $bicepModules = Join-Path $alzEnvironmentDestination $location
        $files += @(Get-ChildItem -Path $bicepModules -Recurse -Filter *.parameters.json)
    }

    foreach ($file in $files) {
        $bicepConfiguration = Get-Content $file.FullName | ConvertFrom-Json -AsHashtable
        $modified = $false
        foreach ($configKey in $configuration.PsObject.Properties) {
            foreach ($target in $configKey.Value.Targets) {

                $propertyNames = $target.Name -split "\."

                $bicepConfig = $bicepConfiguration.parameters

                Write-Host $target.Name

                foreach($propertyName in $propertyNames) {
                    if ($propertyName -eq $propertyNames[-1]) {
                        continue
                    }

                    Write-Host $propertyName

                    if ($bicepConfig.ContainsKey($propertyName) -eq $false) {
                        $bicepConfig = $null
                        break
                    } else {
                        $bicepConfig = $bicepConfig[$propertyName]
                    }
                }

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
