function Request-ConfigurationValue {
    param(
        [Parameter(Mandatory = $true)]
        [object] $configValue
    )

    $allowedValues = $configValue.allowedValues
    $hasAllowedValues = $null -ne $configValue.allowedValues

    $defaultValue = $configValue.defaultValue
    $hasDefaultValue = $null -ne $configValue.defaultValue

    Write-InformationColored $configValue.description -ForegroundColor White -InformationAction Continue
    if ($hasAllowedValues) {
        Write-InformationColored "[allowed: $allowedValues] " -ForegroundColor Yellow -InformationAction Continue
    }

    do {
        Write-InformationColored "$($configValue.name) " -ForegroundColor Yellow -NoNewline -InformationAction Continue
        if ($hasDefaultValue) {
            $displayDefaultValue = $defaultValue -eq "" ? "''" : $defaultValue
            Write-InformationColored "(default: ${displayDefaultValue}): " -ForegroundColor Yellow -NoNewline -InformationAction Continue
        } else {
            Write-InformationColored ": " -NoNewline -InformationAction Continue
        }

        $readValue = Read-Host

        if ($hasDefaultValue -and $readValue -eq "") {
            $configValue.value = $configValue.defaultValue
        } else {
            $configValue.value = $readValue
        }
    }
    while ((($null -eq $configValue.value -or "" -eq $configValue.value) -and ($configValue.value -ne $configValue.defaultValue)) -or ($hasAllowedValues -and $allowedValues.Contains($configValue.value) -eq $false))

    Write-InformationColored "" -InformationAction Continue
}
