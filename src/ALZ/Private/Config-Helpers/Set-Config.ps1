
function Set-Config {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [object] $configurationParameters,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $inputConfig = $null,
        [Parameter(Mandatory = $false)]
        [hashtable] $computedInputs
    )

    if ($PSCmdlet.ShouldProcess("Set Configuration.", "Set configuration values.")) {
        $configurations = $configurationParameters.PsObject.Properties

        foreach ($configurationValue in $configurations) {

            # Check for calculated configuration
            if($configurationValue.Value.Source -eq "calculated") {
                $configurationValue.Value.Value = $configurationValue.Value.Pattern
                continue
            }

            # Look for computed input match
            if($null -ne $computedInputs) {
                $computedInput = $computedInputs[$configurationValue.Name]

                if($null -ne $computedInput) {
                    $configurationValue.Value.Value = $computedInput
                    continue
                }
            }

            # Look for input config match
            $inputConfigName = $configurationValue.Name
            if($configurationValue.PSObject.Properties.Name -contains "SourceInput") {
                $inputConfigName = $configurationValue.SourceInput
            }

            $inputConfigItem = $inputConfig.PsObject.Properties | Where-Object { $_.Name -eq $inputConfigName }
            if($null -ne $inputConfigItem) {
                $configurationValue.Value.Value = $inputConfigItem.Value
                continue
            }

            # TODO: Add validation here...

            # Use the default value if no input config is supplied
            if($configurationValue.Value.PSObject.Properties.Name -match "DefaultValue") {
                Write-Verbose "Input not supplied, so using default value of $($configurationValue.Value.DefaultValue) for $($configurationValue.Name)"
                $configurationValue.Value.Value = $configurationValue.Value.DefaultValue
                continue
            }

            Write-InformationColored "Input not supplied, and no default for $($configurationValue.Name)..." -ForegroundColor Red -InformationAction Continue
            throw "Input not supplied, and no default for $($configurationValue.Name)..."
        }

        return $configurationParameters
    }
}
