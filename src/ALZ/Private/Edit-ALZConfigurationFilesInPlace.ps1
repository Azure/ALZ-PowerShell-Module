$alzBicepModulesRoot = "/infra-as-code/bicep/modules"

function Edit-ALZConfigurationFilesInPlace {
    param(
        [Parameter(Mandatory = $true)]
        [string] $alzBicepRoot,

        [Parameter(Mandatory = $true)]
        [object] $configuration
    )

    # Temporary location to the bicep modules and by extension configuration.
    $bicepModules = Join-Path $alzBicepRoot $alzBicepModulesRoot

    $files = @(Get-ChildItem -Path $bicepModules -Recurse -Filter *.parameters.*.json)

    foreach ($file in $files) {
        $bicepConfiguration = Get-Content $file.FullName | ConvertFrom-Json -AsHashtable
        $modified = $false
        foreach ($configKey in $configuration.PsObject.Properties) {
            foreach ($name in $configKey.Value.Names) {
                if ($null -ne $bicepConfiguration.parameters[$name]) {
                    $bicepConfiguration.parameters[$name].value = $configKey.Value.Value
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
