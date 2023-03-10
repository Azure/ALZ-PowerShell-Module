function Initialize-ALZBicepConfigFiles {
    param (
        [Parameter(Mandatory = $true)]
        [string] $alzEnvironmentDestination,
        [Parameter(Mandatory = $true)]
        [string] $alzBicepVersion,
        [Parameter(Mandatory = $false)]
        [object] $configuration
    )
    $scriptRoot = Get-ScriptRoot
    $configPath = Join-Path $scriptRoot "../Assets/alz-bicep-config/$alzBicepVersion.config.json"
    #remove v from version
    $alzBicepVersion = $alzBicepVersion -replace "^v"
    $bicepPath = Join-Path $scriptRoot "../Assets/alz-bicep-internal/ALZ-BICEP-$alzBicepVersion"
    # get the config from to this bicep version
    $bicepConfig = Get-Content -Path $configPath | ConvertFrom-Json
    Write-Host "Initializing ALZ Bicep config files for version $alzBicepVersion"
    $modulesPath = Join-Path $bicepPath $bicepConfig.modules_path
    $orchestrationPath = Join-Path $bicepPath $bicepConfig.orchestration_path
    $bicepConfig.bootstrap_modules.PsObject.Properties | ForEach-Object {
        Write-Host "Initializing config file for module $($_.Name)"
        $config = $_.Value
        $name = ""
        if($config.sources.Count -ne 1) {
            # select the source based on selection_property value
            $selectIndex = $configuration[$config.selection_property].Value
            $source = $config.sources[$selectIndex]
        } else {
            $source = $config.sources[0]
        }
        if($config.type -eq "module") {
            $source = Join-Path $bicepConfig.modules_path $source
        } elseif ($config.type -eq "orchestration") {
            $source = Join-Path $bicepConfig.orchestration_path $source
        } else {
            Write-Error "Invalid config type $config.type"
        }
        # Get parameter file for this source
        $parameterFile = Join-Path $source "parameters" ""
    }
    return $true
}