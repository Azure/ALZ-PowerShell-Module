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
                if ($target.Destination -eq "Parameters" -and $null -ne $bicepConfiguration.parameters[$target.Name]) {
                    if ($configKey.Value.Type -eq "Computed") {
                        $bicepConfiguration.parameters[$target.Name].value = Format-TokenizedConfigurationString $configKey.Value.Value $configuration
                    } else {
                        $bicepConfiguration.parameters[$target.Name].value = $configKey.Value.Value
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
