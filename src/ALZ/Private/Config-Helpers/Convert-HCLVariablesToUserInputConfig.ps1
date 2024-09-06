function Convert-HCLVariablesToUserInputConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $targetVariableFile,

        [Parameter(Mandatory = $false)]
        [string] $hclParserToolPath,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$validators,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$appendToObject = $null,

        [Parameter(Mandatory = $false)]
        [switch]$allComputedInputs
    )

    if ($PSCmdlet.ShouldProcess("Parse HCL Variables into Config", "modify")) {
        $terraformVariables = & $hclParserToolPath $targetVariableFile | ConvertFrom-Json

        $starterModuleConfiguration = [PSCustomObject]@{}
        if($appendToObject -ne $null) {
            $starterModuleConfiguration = $appendToObject
        }

        foreach($variable in $terraformVariables.variable.PSObject.Properties) {
            $description = $variable.Value[0].description
            $validationTypeSplit = $description -split "\|"

            $hasValidation = $false
            $order = 0

            if($validationTypeSplit.Length -gt 1) {
                $description = $validationTypeSplit[0].Trim()
            }

            if($validationTypeSplit.Length -eq 2) {
                $splitItem = $validationTypeSplit[1].Trim()
                if($splitItem -match "^\d+$") {
                    $order = [convert]::ToInt32($splitItem)
                } else {
                    $validationType = $splitItem
                    $hasValidation = $true
                }
            }

            if($validationTypeSplit.Length -eq 3) {
                $order = [convert]::ToInt32($validationTypeSplit[1].Trim())
                $validationType = $validationTypeSplit[2].Trim()
                $hasValidation = $true
            }

            $inputType = "UserInput"
            if($allComputedInputs) {
                $inputType = "ComputedInput"
                Write-Verbose "Name: $($variable.Name), Has Validation: $hasValidation, Order: $order, ValidationType: $validationType, Description: $description, InputType: $inputType"
            }

            $sensitive = $false
            if($variable.Value[0].PSObject.Properties.Name -contains "sensitive") {
                $sensitive = $true
            }

            $dataType = $variable.Value[0].type
            $dataType = $dataType.Replace("`${", "").Replace("}", "")

            $starterModuleConfigurationInstance = [PSCustomObject]@{}
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Order" -NotePropertyValue $order
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Type" -NotePropertyValue $inputType
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Value" -NotePropertyValue ""
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "DataType" -NotePropertyValue $dataType
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Sensitive" -NotePropertyValue $sensitive
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Source" -NotePropertyValue "UserInterface"

            if($variable.Value[0].PSObject.Properties.Name -contains "default") {
                $defaultValue = $variable.Value[0].default

                if($variable.Value[0].default.GetType().Name -eq "Boolean") {
                    $defaultValue = $variable.Value[0].default.ToString().ToLower()
                }
                if($dataType -eq "list(string)") {
                    $defaultValueRaw = $variable.Value[0].default
                    $defaultValue = ""
                    if($defaultValue.Length -gt 0) {
                        $join = $defaultValueRaw -join "`",`""
                        $defaultValue = "`"$join`""
                    }
                }
                $starterModuleConfigurationInstance | Add-Member -NotePropertyName "DefaultValue" -NotePropertyValue $defaultValue
            }

            if($hasValidation) {
                Write-Verbose "Validation: $hasValidation - $validationType"
                $validator = $validators.PSObject.Properties[$validationType].Value
                $description = "$description ($($validator.Description))"
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