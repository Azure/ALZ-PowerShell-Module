function Convert-HCLVariablesToUserInputConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $targetVariableFile,

        [Parameter(Mandatory = $false)]
        [string] $hclParserToolPath
    )

    if ($PSCmdlet.ShouldProcess("Parse HCL Variables into Config", "modify")) {
        $terraformVariables = & $hclParserToolPath $targetVariableFile | ConvertFrom-Json

        $starterModuleConfiguration = [PSCustomObject]@{}

        foreach($variable in $terraformVariables.variable.PSObject.Properties) {
            $starterModuleConfigurationInstance = [PSCustomObject]@{}
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Type" -NotePropertyValue "UserInput"
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Description" -NotePropertyValue $variable.Value[0].description
            $starterModuleConfigurationInstance | Add-Member -NotePropertyName "Value" -NotePropertyValue ""
            $starterModuleConfiguration | Add-Member -NotePropertyName $variable.Name -NotePropertyValue $starterModuleConfigurationInstance
        }
    }

    return $starterModuleConfiguration
}