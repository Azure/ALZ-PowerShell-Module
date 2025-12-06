function Convert-HCLVariablesToInputConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $targetVariableFile,

        [Parameter(Mandatory = $false)]
        [string] $hclParserToolPath,

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
            }

            $configItem = [PSCustomObject]@{}
            $configItem | Add-Member -NotePropertyName "Value" -NotePropertyValue ""
            $configItem | Add-Member -NotePropertyName "Source" -NotePropertyValue "input"

            if ($variable.Value[0].PSObject.Properties.Name -contains "default") {
                $configItem | Add-Member -NotePropertyName "DefaultValue" -NotePropertyValue $variable.Value[0].default
            }

            $configItem | Add-Member -NotePropertyName "Description" -NotePropertyValue $description

            $sensitive = $false
            if ($variable.Value[0].PSObject.Properties.Name -contains "sensitive" -and $variable.Value[0].sensitive -eq $true) {
                $sensitive = $true
                Write-Verbose "Marking variable $($variable.Name) as sensitive..."
            }
            $configItem | Add-Member -NotePropertyName "Sensitive" -NotePropertyValue $sensitive

            Write-Verbose "Adding variable $($variable.Name) to the configuration..."
            $configItems | Add-Member -NotePropertyName $variable.Name -NotePropertyValue $configItem
        }
    }

    return $configItems
}
