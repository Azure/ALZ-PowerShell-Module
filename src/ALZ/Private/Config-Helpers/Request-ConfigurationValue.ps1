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

    $dataType = $configValue.DataType
    Write-Verbose "Data Type: $dataType"

    $attempt = 0
    $maxAttempts = 10

    do {
        Write-InformationColored "$($configName) " -ForegroundColor Yellow -NoNewline -InformationAction Continue
        if ($hasDefaultValue) {
            $displayDefaultValue = $defaultValue -eq "" ? "''" : $defaultValue
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

        if ($hasDefaultValue -and $readValue -eq "") {
            $configValue.Value = $configValue.defaultValue
        } else {
            $configValue.Value = $readValue
        }

        $valuesToCheck = @( $configValue.Value )
        if($dataType -eq "list(string)") {
            $valuesToCheck = ($configValue.Value -split ",").Trim() | Where-Object {$_ -ne ''}
            $configValue.Value = $valuesToCheck -join ","
        }

        $isValid = $false

        foreach($valueToCheck in $valuesToCheck) {
            $isValid = $true

            $hasNotSpecifiedValue = ($null -eq $valueToCheck -or "" -eq $valueToCheck) -and ($valueToCheck -ne $configValue.DefaultValue)

            if($hasNotSpecifiedValue) {
                Write-InformationColored "A value must be specified for this input. It cannot be left empty." -ForegroundColor Red -InformationAction Continue
                $isValid = $false
                break
            }

            $skipValidationForEmptyDefault = $treatEmptyDefaultAsValid -and $hasDefaultValue -and (($defaultValue -eq "" -and $valueToCheck -eq ""))
            if(!$skipValidationForEmptyDefault) {
                if($hasAllowedValues) {
                    Write-Verbose "Checking '$($valueToCheck)' against list '$($allowedValues)'"
                    $isValid = $allowedValues.Contains($valueToCheck)
                    if(!$isValid) {
                        Write-InformationColored "The input value '$valueToCheck' is not valid. It must be in the allowed list: '$($allowedValues)'" -ForegroundColor Red -InformationAction Continue
                        break
                    }
                }

                if($hasValidator) {
                    Write-Verbose "Checking '$($valueToCheck)' against validator '$($configValue.Valid)'"
                    $isValid = $valueToCheck -match $configValue.Valid
                    if(!$isValid) {
                        Write-InformationColored "The input value '$valueToCheck' is not valid. It must match to specified regular expression: '$($configValue.Valid)'" -ForegroundColor Red -InformationAction Continue
                        break
                    }
                }
            }
        }

        $shouldRetry = !$isValid -and $withRetries

        $attempt += 1
    }
    while ($shouldRetry -and $attempt -lt $maxAttempts)

    if($attempt -eq $maxAttempts) {
        Write-InformationColored "Max attempts reached for getting input value. Exiting..." -ForegroundColor Red -InformationAction Continue
        throw "Max attempts reached for getting input value. Exiting..."
    }
}
