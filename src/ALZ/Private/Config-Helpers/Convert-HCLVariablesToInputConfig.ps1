function Convert-HCLVariablesToInputConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $targetVariableFile,

        [Parameter(Mandatory = $false)]
        [string] $hclParserToolPath,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$validators,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$appendToObject = $null
    )

    if ($PSCmdlet.ShouldProcess("Parse HCL Variables into Config", "modify")) {
        $terraformVariables = & $hclParserToolPath $targetVariableFile | ConvertFrom-Json

        if ($terraformVariables.PSObject.Properties.Name -notcontains "variable") {
            Write-Verbose "No variables found in $targetVariableFile, skipping..."
            return $appendToObject
        }

        Write-Verbose "Variables found in $targetVariableFile, processing..."

        $configItems = [PSCustomObject]@{}
        if ($appendToObject -ne $null) {
            $configItems = $appendToObject
        }

        foreach ($variable in $terraformVariables.variable.PSObject.Properties) {
            if ($variable.Value[0].PSObject.Properties.Name -contains "description") {
                $description = $variable.Value[0].description
                $validationTypeSplit = $description -split "\|"

                $hasValidation = $false

                if ($validationTypeSplit.Length -gt 1) {
                    $description = $validationTypeSplit[0].Trim()
                }

                if ($validationTypeSplit.Length -eq 2) {
                    $splitItem = $validationTypeSplit[1].Trim()
                    $validationType = $splitItem
                    $hasValidation = $true
                }
            }

            $configItem = [PSCustomObject]@{}
            $configItem | Add-Member -NotePropertyName "Value" -NotePropertyValue ""
            $configItem | Add-Member -NotePropertyName "Source" -NotePropertyValue "input"

            if ($variable.Value[0].PSObject.Properties.Name -contains "default") {
                $configItem | Add-Member -NotePropertyName "DefaultValue" -NotePropertyValue $variable.Value[0].default
            }

            if ($hasValidation) {
                $validator = $validators.PSObject.Properties[$validationType].Value
                $description = "$description ($($validator.Description))"
                if ($validator.Type -eq "AllowedValues") {
                    $configItem | Add-Member -NotePropertyName "AllowedValues" -NotePropertyValue $validator.AllowedValues
                }
                if ($validator.Type -eq "Valid") {
                    $configItem | Add-Member -NotePropertyName "Valid" -NotePropertyValue $validator.Valid
                }
                $configItem | Add-Member -NotePropertyName "Validator" -NotePropertyValue $validationType
            }

            $configItem | Add-Member -NotePropertyName "Description" -NotePropertyValue $description

            Write-Verbose "Adding variable $($variable.Name) to the configuration..."
            $configItems | Add-Member -NotePropertyName $variable.Name -NotePropertyValue $configItem
        }
    }

    return $configItems
}
