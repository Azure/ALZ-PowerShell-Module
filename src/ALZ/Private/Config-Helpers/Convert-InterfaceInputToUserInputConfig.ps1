function Convert-InterfaceInputToUserInputConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$inputConfig,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$validators,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$appendToObject = $null
    )

    if ($PSCmdlet.ShouldProcess("Parse Interface Variables into Config", "modify")) {

        $starterModuleConfiguration = [PSCustomObject]@{}
        if($appendToObject -ne $null) {
            $starterModuleConfiguration = $appendToObject
        }

        Write-Verbose $validators

        foreach($variable in $inputConfig.inputs.PSObject.Properties) {
            Write-Verbose "Parsing variable $($variable.Name)"
            $description = $variable.Value.description

            $order = 0
            if($variable.PSObject.Properties.Name -contains "display_order") {
                $order = $variable.Value.display_order
            }

            $inputType = $variable.Value.source -eq "input" ? "UserInput" : "ComputedInput"
            $dataType = $variable.Value.type

            $sensitive = $false
            if($variable.Value.PSObject.Properties.Name -contains "sensitive") {
                $sensitive = $variable.Value.sensitive
            }

            $starterModuleConfigurationInstance = [PSCustomObject]@{}
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Order" -NotePropertyValue $order
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Type" -NotePropertyValue $inputType
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "DataType" -NotePropertyValue $dataType
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Sensitive" -NotePropertyValue $sensitive

            if($variable.Value.PSObject.Properties.Name -contains "Value") {
                $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Value" -NotePropertyValue $variable.Value.Value
            } else {
                $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Value" -NotePropertyValue ""
            }

            if($variable.Value.PSObject.Properties.Name -contains "default") {
                $defaultValue = $variable.Value.default
                $starterModuleConfigurationInstance | Add-Member -NotePropertyName "DefaultValue" -NotePropertyValue $defaultValue
            }

            if($variable.Value.PSObject.Properties.Name -contains "validation") {
                $validationType = $variable.Value.validation
                $validator = $validators.PSObject.Properties[$validationType].Value
                $description = "$description ($($validator.Description))"
                Write-Verbose "Adding $($variable.Value.validation) validation for $($variable.Name). Validation type: $($validator.Type)"
                if($validator.Type -eq "AllowedValues"){
                    $starterModuleConfigurationInstance | Add-Member -NotePropertyName "AllowedValues" -NotePropertyValue $validator.AllowedValues
                }
                if($validator.Type -eq "Valid"){
                    $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Valid" -NotePropertyValue $validator.Valid
                }
                $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Validator" -NotePropertyValue $validationType
            }

            if($variable.Value.PSObject.Properties.Name -contains "Targets") {
                $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Targets" -NotePropertyValue $variable.Value.Targets
            }

            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Description" -NotePropertyValue $description
            $starterModuleConfiguration | Add-Member -NotePropertyName $variable.Name -NotePropertyValue $starterModuleConfigurationInstance
        }
    }

    return $starterModuleConfiguration
}