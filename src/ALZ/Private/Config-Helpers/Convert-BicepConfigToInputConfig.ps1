function Convert-BicepConfigToInmputConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$bicepConfig,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$validators,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$appendToObject = $null
    )

    if ($PSCmdlet.ShouldProcess("Parse Interface Variables into Config", "modify")) {

        $configItems = [PSCustomObject]@{}
        if($appendToObject -ne $null) {
            $configItems = $appendToObject
        }

        Write-Verbose $validators

        foreach($variable in $bicepConfig.inputs.PSObject.Properties) {
            Write-Verbose "Parsing variable $($variable.Name)"
            $description = $variable.Value.description

            $configItem = [PSCustomObject]@{}
            $configItem | Add-Member -NotePropertyName "Source" -NotePropertyValue $variable.Value.source
            $configItem | Add-Member -NotePropertyName "Value" -NotePropertyValue ""

            if($variable.Value.PSObject.Properties.Name -contains "sourceInput") {
                $configItem | Add-Member -NotePropertyName "SourceInput" -NotePropertyValue $variable.Value.sourceInput
            }

            if($variable.Value.PSObject.Properties.Name -contains "pattern") {
                $configItem | Add-Member -NotePropertyName "Pattern" -NotePropertyValue $variable.Value.pattern
            }

            if($variable.Value.PSObject.Properties.Name -contains "default") {
                $defaultValue = $variable.Value.default
                $configItem | Add-Member -NotePropertyName "DefaultValue" -NotePropertyValue $defaultValue
            }

            if($variable.Value.PSObject.Properties.Name -contains "validation") {
                $validationType = $variable.Value.validation
                $validator = $validators.PSObject.Properties[$validationType].Value
                $description = "$description ($($validator.Description))"
                Write-Verbose "Adding $($variable.Value.validation) validation for $($variable.Name). Validation type: $($validator.Type)"
                if($validator.Type -eq "AllowedValues"){
                    $configItem | Add-Member -NotePropertyName "AllowedValues" -NotePropertyValue $validator.AllowedValues
                }
                if($validator.Type -eq "Valid"){
                    $configItem | Add-Member -NotePropertyName "Valid" -NotePropertyValue $validator.Valid
                }
                $configItem | Add-Member -NotePropertyName "Validator" -NotePropertyValue $validationType
            }

            if($variable.Value.PSObject.Properties.Name -contains "targets") {
                $configItem | Add-Member -NotePropertyName "targets" -NotePropertyValue $variable.Value.targets
            }

            $configItem | Add-Member -NotePropertyName "Description" -NotePropertyValue $description
            $configItems | Add-Member -NotePropertyName $variable.Name -NotePropertyValue $configItem
        }
    }

    return $configItems
}