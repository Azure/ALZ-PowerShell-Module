function Import-ConfigurationFileData {
    <#

    #>
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $starterModuleConfiguration,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $bootstrapConfiguration
    )

    $configurationFilePathObjects = ($starterModuleConfiguration.PsObject.Properties | Where-Object { $_.Value.Validator -eq "configuration_file_path" })

    if($configurationFilePathObjects.Count -eq 0) {
        return
    }

    $configurationFilePath = $configurationFilePathObjects[0].Value.Value
    $bootstrapConfigurationFilePathObject = $bootstrapConfiguration.PsObject.Properties | Where-Object { $_.Value.Validator -eq "hidden_configuration_file_path" }
    $bootstrapConfigurationFilePathObject.Value.Value = $configurationFilePath
}