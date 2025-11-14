# If the value type is computed we replace the value with another which already exists in the configuration hierarchy.
function Set-ComputedConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $configuration
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Bicep computed configuration.", "calculate computed values")) {
        foreach ($configKey in $configuration.PsObject.Properties) {
            if ("calculated" -ne $configKey.Value.Source) {
                continue;
            }

            if ($configKey.Value.Value -is [array]) {
                $formattedValues = @()
                foreach ($formatString in $configKey.Value.Value) {
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
}
