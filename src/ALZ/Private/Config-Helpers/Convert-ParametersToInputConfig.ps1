function Convert-ParametersToInputConfig {
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $inputConfig,
        [Parameter(Mandatory = $false)]
        [hashtable] $parameters
    )

    foreach ($parameterKey in $parameters.Keys) {
        $parameter = $parameters[$parameterKey]
        Write-Verbose "Processing parameter $parameterKey $(ConvertTo-Json $parameter -Depth 100)"

        foreach ($parameterAlias in $parameter.aliases) {
            if ($inputConfig.PsObject.Properties.Name -contains $parameterAlias) {
                Write-Verbose "Alias $parameterAlias exists in input config, renaming..."
                $configItem = $inputConfig.PSObject.Properties | Where-Object { $_.Name -eq $parameterAlias }
                $inputConfig | Add-Member -NotePropertyName $parameterKey -NotePropertyValue @{
                    Value  = $configItem.Value.Value
                    Source = $configItem.Value.Source
                }
                $inputConfig.PSObject.Properties.Remove($configItem.Name)
                continue
            }
        }

        if ($inputConfig.PsObject.Properties.Name -notcontains $parameterKey) {
            $variableValue = [Environment]::GetEnvironmentVariable("ALZ_$($parameterKey)")
            if ($null -eq $variableValue) {
                if ($parameter.type -eq "SwitchParameter") {
                    $variableValue = $parameter.value.IsPresent
                } else {
                    $variableValue = $parameter.value
                }
            }

            if ($parameter.type -eq "SwitchParameter") {
                $variableValue = [bool]::Parse($variableValue)
            }
            Write-Verbose "Adding parameter $parameterKey with value $variableValue"
            $inputConfig | Add-Member -NotePropertyName $parameterKey -NotePropertyValue @{
                Value  = $variableValue
                Source = "parameter"
            }
        }
    }

    return $inputConfig
}
