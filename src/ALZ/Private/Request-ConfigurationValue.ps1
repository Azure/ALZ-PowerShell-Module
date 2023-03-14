function Request-ConfigurationValue {
    param(
        [Parameter(Mandatory = $true)]
        [string] $configName,

        [Parameter(Mandatory = $true)]
        [object] $configValue,

        [Parameter(Mandatory = $false)]
        [System.Boolean] $withRetries = $true
    )

    $allowedValues = $configValue.AllowedValues
    $hasAllowedValues = $null -ne $configValue.AllowedValues

    $defaultValue = $configValue.DefaultValue
    $hasDefaultValue = $null -ne $configValue.DefaultValue

    $hasValidator = $null -ne $configValue.Valid

    Write-InformationColored $configValue.Description -ForegroundColor White -InformationAction Continue
    if ($hasAllowedValues) {
        Write-InformationColored "[allowed: $allowedValues] " -ForegroundColor Yellow -InformationAction Continue
    }

    do {
        Write-InformationColored "$($configName) " -ForegroundColor Yellow -NoNewline -InformationAction Continue
        if ($hasDefaultValue) {
            $displayDefaultValue = $defaultValue -eq "" ? "''" : $defaultValue
            Write-InformationColored "(default: ${displayDefaultValue}): " -ForegroundColor Yellow -NoNewline -InformationAction Continue
        } else {
            Write-InformationColored ": " -NoNewline -InformationAction Continue
        }

        $readValue = Read-Host

        $previousValue = $configValue.Value

        if ($hasDefaultValue -and $readValue -eq "") {
            $configValue.Value = $configValue.defaultValue
        } else {
            $configValue.Value = $readValue
        }

        $hasNotSpecifiedValue = ($null -eq $configValue.Value -or "" -eq $configValue.Value) -and ($configValue.Value -ne $configValue.DefaultValue)
        $isDisallowedValue = $hasAllowedValues -and $allowedValues.Contains($configValue.Value) -eq $false
        $isNotValid = $hasValidator -and $configValue.Value -match $configValue.Valid -eq $false

        if ($hasNotSpecifiedValue -or $isDisallowedValue -or $isNotValid) {
            Write-InformationColored "Please specify a valid value for this field." -ForegroundColor Red -InformationAction Continue
            $configValue.Value = $previousValue
            $validationError = $true
        }

        $shouldRetry = $validationError -and $withRetries
    }
    while (($hasNotSpecifiedValue -or $isDisallowedValue -or $isNotValid) -and $shouldRetry)

    Write-InformationColored "" -InformationAction Continue
}
