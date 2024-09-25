
function Request-ALZEnvironmentConfig {
    param(
        [Parameter(Mandatory = $true)]
        [object] $configurationParameters,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $inputConfig = $null,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $computedInputs = $null

    )

    $configurations = $configurationParameters.PsObject.Properties

    if($null -ne $computedInputs) {
        Write-Verbose $computedInputs
    }
    foreach ($configurationValue in $configurations) {
        $computedInput = $null
        if($null -ne $computedInputs) {
            $computedInput = $computedInputs.PsObject.Properties | Where-Object { $_.Name -eq $configurationValue.Name }
        }

        if($null -ne $computedInput) {
            $configurationValue.Value.Value = $computedInput.Value.Value
            continue
        }

        if ($configurationValue.Value.Type -eq "UserInput") {
            $inputConfigItem = $inputConfig.PsObject.Properties | Where-Object { $_.Name -eq $configurationValue.Name }
            if($null -ne $inputConfigItem) {
                $configurationValue.Value.Value = $inputConfigItem.Value
                $configurationValue.Value.Source = "InputConfig"
            } else {
                if($configurationValue.Value.PSObject.Properties.Name -match "DefaultValue") {
                    Write-Verbose "Input not supplied, so using default value of $($configurationValue.Value.DefaultValue) for $($configurationValue.Name)"
                    $configurationValue.Value.Value = $configurationValue.Value.DefaultValue
                } else {
                    Write-InformationColored "Input not supplied, and no default for $($configurationValue.Name)..." -ForegroundColor Red -InformationAction Continue
                    throw "Input not supplied, and no default for $($configurationValue.Name)..."
                }
            }
        }
    }

    return $configurationParameters
}