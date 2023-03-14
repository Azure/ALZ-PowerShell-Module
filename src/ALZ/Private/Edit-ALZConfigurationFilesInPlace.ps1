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

    $locations = @("orchestration", "customization")
    $files = @()

    foreach ($location in $locations) {
        $bicepModules = Join-Path $alzEnvironmentDestination $location
        $files += @(Get-ChildItem -Path $bicepModules -Recurse -Filter *.parameters.json)
    }

    foreach ($file in $files) {
        $bicepConfiguration = Get-Content $file.FullName | ConvertFrom-Json -AsHashtable
        $modified = $false
        foreach ($configKey in $configuration.PsObject.Properties) {
            foreach ($name in $configKey.Value.Names) {
                if ($null -ne $bicepConfiguration.parameters[$name]) {

                    # If we've specified a string to replace - and the value contains that string, then replace it.
                    # Otherwise overwrite the value completely.
                    if ($null -ne $configKey.Value.Replace) {
                        $bicepConfiguration.parameters[$name].value = `
                            $bicepConfiguration.parameters[$name].value -replace $configKey.Value.Replace, $configKey.Value.Value
                    } else {
                        $bicepConfiguration.parameters[$name].value = $configKey.Value.Value
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
