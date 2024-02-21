function Convert-InterfaceInputToUserInputConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $inputConfig,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$validators,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$appendToObject = $null
    )

    if ($PSCmdlet.ShouldProcess("Parse HCL Variables into Config", "modify")) {

        $starterModuleConfiguration = [PSCustomObject]@{}
        if($appendToObject -ne $null) {
            $starterModuleConfiguration = $appendToObject
        }

        foreach($variable in $inputConfig.PSObject.Properties) {
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
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Value" -NotePropertyValue ""
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "DataType" -NotePropertyValue $dataType
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Sensitive" -NotePropertyValue $sensitive

            if($variable.Value[0].PSObject.Properties.Name -contains "default") {
                $defaultValue = $variable.Value.default
                $starterModuleConfigurationInstance | Add-Member -NotePropertyName "DefaultValue" -NotePropertyValue $defaultValue
            }

            if($variable.PSObject.Properties.Name -contains "validation") {
                $validationType = $variable.Value.validation
                $validator = $validators.PSObject.Properties[$validationType].Value
                if($validator.Type -eq "AllowedValues"){
                    $starterModuleConfigurationInstance | Add-Member -NotePropertyName "AllowedValues" -NotePropertyValue $validator.AllowedValues
                }
                if($validator.Type -eq "Valid"){
                    $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Valid" -NotePropertyValue $validator.Valid
                }
                $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Validator" -NotePropertyValue $validationType
            }

            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Description" -NotePropertyValue $description
            $starterModuleConfiguration | Add-Member -NotePropertyName $variable.Name -NotePropertyValue $starterModuleConfigurationInstance
        }
    }

    return $starterModuleConfiguration
}