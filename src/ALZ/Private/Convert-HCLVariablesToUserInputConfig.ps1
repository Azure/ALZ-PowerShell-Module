function Convert-HCLVariablesToUserInputConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $targetVariableFile,

        [Parameter(Mandatory = $false)]
        [string] $hclParserToolPath,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$validators
    )

    if ($PSCmdlet.ShouldProcess("Parse HCL Variables into Config", "modify")) {
        $terraformVariables = & $hclParserToolPath $targetVariableFile | ConvertFrom-Json

        $starterModuleConfiguration = [PSCustomObject]@{}

        foreach($variable in $terraformVariables.variable.PSObject.Properties) {
            $description = $variable.Value[0].description
            $validationTypeSplit = $description -split "\|"

            $hasValidation = $false
            if($validationTypeSplit.Length -gt 1) {
                $validationType = $validationTypeSplit[1].Trim()
                $description = $validationTypeSplit[0].Trim()
                $hasValidation = $true
            }

            $starterModuleConfigurationInstance = [PSCustomObject]@{}
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Type" -NotePropertyValue "UserInput"
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Value" -NotePropertyValue ""
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "DataType" -NotePropertyValue $variable.Value[0].type

            if($variable.Value[0].PSObject.Properties.Name -contains "default") {
                $starterModuleConfigurationInstance | Add-Member -NotePropertyName "DefaultValue" -NotePropertyValue $variable.Value[0].default
            }

            if($hasValidation) {
                $validator = $validators.PSObject.Properties[$validationType].Value
                $description = "$description ($($validator.Description))"
                if($validator.Type -eq "AllowedValues"){
                    $starterModuleConfigurationInstance | Add-Member -NotePropertyName "AllowedValues" -NotePropertyValue $validator.AllowedValues
                }
                if($validator.Type -eq "Valid"){
                    $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Valid" -NotePropertyValue $validator.Valid
                }
            }

            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Description" -NotePropertyValue $description

            $starterModuleConfiguration | Add-Member -NotePropertyName $variable.Name -NotePropertyValue $starterModuleConfigurationInstance
        }
    }

    return $starterModuleConfiguration
}