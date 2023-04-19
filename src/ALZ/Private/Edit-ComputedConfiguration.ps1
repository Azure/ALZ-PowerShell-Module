# If the value type is computed we replace the value with another which already exists in the configuration hierarchy.
function Edit-ComputedConfiguration {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $configuration
    )

    foreach ($configKey in $configuration.PsObject.Properties) {
        if ($configKey.Value.Type -ne "Computed") {
            continue;
        }

        if ($configKey.Value.Value -is [array]) {
            $formattedValues = @()
            foreach($formatString in $configKey.Value.Value) {
                $formattedValues += Format-TokenizedConfigurationString -tokenizedString $formatString -configuration $configuration
            }

            if ($null -ne $configKey.Value.Process) {
                $scriptBlock = [ScriptBlock]::Create($configKey.Value.Process)
                $formattedValues = Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $formattedValues
                $formattedValues = @($formattedValues)
            }

            $configKey.Value.Value = $formattedValues
        } else {

            $formattedValue = Format-TokenizedConfigurationString -tokenizedString $configKey.Value.Value -configuration $configuration

            if ($null -ne $configKey.Value.Process) {
                $scriptBlock = [ScriptBlock]::Create($configKey.Value.Process)
                $formattedValue = Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $formattedValue
            }

            $configKey.Value.Value = $formattedValue
        }
    }
}