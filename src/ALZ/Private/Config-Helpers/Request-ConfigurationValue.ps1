function Request-ConfigurationValue {
    param(
        [Parameter(Mandatory = $true)]
        [string] $configName,

        [Parameter(Mandatory = $true)]
        [object] $configValue,

        [Parameter(Mandatory = $false)]
        [System.Boolean] $withRetries = $true,

        [Parameter(Mandatory = $false)]
        [System.Boolean] $treatEmptyDefaultAsValid = $false
    )

    #if the file has a script - execute it:
    if ($null -ne $configValue.AllowedValues -and $configValue.AllowedValues.Type -eq "PSScript") {
        Write-InformationColored $configValue.AllowedValues.Description -ForegroundColor Yellow -InformationAction Continue
        $script = [System.Management.Automation.ScriptBlock]::Create($configValue.AllowedValues.Script)
        $configValue.AllowedValues.Values = Invoke-Command -ScriptBlock $script
    }

    $allowedValues = $configValue.AllowedValues.Values
    $hasAllowedValues = $null -ne $configValue.AllowedValues -and $null -ne $configValue.AllowedValues.Values -and $configValue.AllowedValues.Values.Length -gt 0

    $defaultValue = $configValue.DefaultValue
    $hasDefaultValue = $null -ne $configValue.DefaultValue

    $hasValidator = $null -ne $configValue.Valid

    Write-InformationColored $configValue.Description -ForegroundColor White -InformationAction Continue
    if ($hasAllowedValues -and $configValue.AllowedValues.Display -eq $true) {
        Write-InformationColored "[allowed: $allowedValues] " -ForegroundColor Yellow -InformationAction Continue
    }

    do {
        Write-InformationColored "$($configName) " -ForegroundColor Yellow -NoNewline -InformationAction Continue
        if ($hasDefaultValue) {
            if ($defaultValue -eq "") {
                $displayDefaultValue = "''"
            } else {
                $displayDefaultValue = $defaultValue
            }
            if($configValue.Sensitive -and $defaultValue -ne "") {
                $displayDefaultValue = "<sensitive>"
            }
            Write-InformationColored "(default: ${displayDefaultValue}): " -ForegroundColor Yellow -NoNewline -InformationAction Continue
        } else {
            Write-InformationColored ": " -NoNewline -InformationAction Continue
        }

        if($configValue.Sensitive) {
            $readValue = Read-Host -MaskInput
        } else {
            $readValue = Read-Host
        }

        $previousValue = $configValue.Value

        if ($hasDefaultValue -and $readValue -eq "") {
            $configValue.Value = $configValue.defaultValue
        } else {
            $configValue.Value = $readValue
        }

        $hasNotSpecifiedValue = ($null -eq $configValue.Value -or "" -eq $configValue.Value) -and ($configValue.Value -ne $configValue.DefaultValue)
        $isDisallowedValue = $hasAllowedValues -and $allowedValues.Contains($configValue.Value) -eq $false
        $skipValidationForEmptyDefault = $treatEmptyDefaultAsValid -and $hasDefaultValue -and (($defaultValue -eq "" -and $configValue.Value -eq "") -or ($configValue.Value -eq "-"))

        # Reset the value to empty if we have a default and the user entered a dash (this is to handle cached situations and provide a method to clear a value)
        if($skipValidationForEmptyDefault -and $configValue.Value -eq "-") {
            $configValue.Value = ""
        }

        if($skipValidationForEmptyDefault) {
            $isNotValid = $false
        } else {
            $isNotValid = $hasValidator -and $configValue.Value -match $configValue.Valid -eq $false
        }

        if ($hasNotSpecifiedValue -or $isDisallowedValue -or $isNotValid) {
            Write-InformationColored "Please specify a valid value for this field." -ForegroundColor Red -InformationAction Continue
            $configValue.Value = $previousValue
            $validationError = $true
        }

        $shouldRetry = $validationError -and $withRetries
    }
    while (

    ($hasNotSpecifiedValue -or $isDisallowedValue -or $isNotValid) -and $shouldRetry)

    Write-InformationColored "" -InformationAction Continue
}
