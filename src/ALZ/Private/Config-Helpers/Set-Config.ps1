
function Set-Config {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [object] $configurationParameters,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $inputConfig = $null,
        [Parameter(Mandatory = $false)]
        [switch] $copyEnvVarToConfig
    )

    if ($PSCmdlet.ShouldProcess("Set Configuration.", "Set configuration values.")) {

        $configurations = $configurationParameters.PsObject.Properties

        foreach ($configurationValue in $configurations) {

            # Check for calculated configuration
            if($configurationValue.Value.Source -eq "calculated") {
                $configurationValue.Value.Value = $configurationValue.Value.Pattern
                continue
            }

            # Get input config name
            $inputConfigName = $configurationValue.Name
            if($configurationValue.Value.PSObject.Properties.Name -contains "SourceInput") {
                $inputConfigName = $configurationValue.Value.SourceInput
                Write-Verbose "Using source input $inputConfigName for $($configurationValue.Name)"
            }

            # Look for environment variables
            $environmentVariable = [Environment]::GetEnvironmentVariable("TF_VAR_$inputConfigName")
            if($null -ne $environmentVariable) {
                if($copyEnvVarToConfig) {
                    $configurationValue.Value.Value = $environmentVariable
                    Write-Verbose "Set value from environment variable for $inputConfigName"
                } else {
                    $configurationValue.Value.Value = "sourced-from-env"
                    Write-Verbose "Using environment variable for $inputConfigName"
                }
                continue
            }

            # Look for collection config match
            if($inputConfigName.EndsWith("]")) {
                Write-Verbose "Looking for collection input config match for $inputConfigName"
                $indexSplit = $inputConfigName.Split([char[]]@('[', ']'), [System.StringSplitOptions]::RemoveEmptyEntries)
                $inputConfigItem = $inputConfig.PsObject.Properties | Where-Object { $_.Name -eq $indexSplit[0] }
                if($null -ne $inputConfigItem) {
                    Write-Verbose "Found collection input config match for $inputConfigName"
                    $inputConfigItemValue = $inputConfigItem.Value.Value
                    $inputConfigItemValueType = $inputConfigItemValue.GetType().FullName
                    Write-Verbose "Input config item value type pre-standardization: $inputConfigItemValueType"

                    # Convert to standard type
                    $inputConfigItemValueJson = ConvertTo-Json -InputObject $inputConfigItemValue -Depth 100
                    Write-Verbose "Input config item value pre-standardization: $inputConfigItemValueJson"
                    $inputConfigItemValue = ConvertFrom-Json -InputObject $inputConfigItemValueJson -Depth 100 -NoEnumerate
                    $inputConfigItemValueType = $inputConfigItemValue.GetType().FullName
                    Write-Verbose "Input config item value type post-standardization: $inputConfigItemValueType"
                    Write-Verbose "Input config item value post-standardization: $(ConvertTo-Json $inputConfigItemValue -Depth 100)"

                    $indexString = $indexSplit[1].Replace("`"", "").Replace("'", "")
                    Write-Verbose "Using index $indexString for input config item $inputConfigName"

                    if([int]::TryParse($indexString, [ref]$null)) {
                        # Handle integer index for arrays
                        Write-Verbose "Handling integer index for array"

                        # Ensure single value array is treated as array
                        if(!$inputConfigItemValueType.EndsWith("]")) {
                            Write-Verbose "Converting single value to array for input config item $($inputConfigName)."
                            $inputConfigItemValue = @($inputConfigItemValue)
                        }

                        $index = [int]$indexString
                        if($inputConfigItemValue.Length -le $index) {
                            Write-Verbose "Input config item $($inputConfigName) does not have an index of $index."
                            if($index -eq 0) {
                                Write-Error "At least one value is required for input config item $($inputConfigName)."
                                throw "At least one value is required for input config item $($inputConfigName)."
                            }
                        } else {
                            try{
                                $inputConfigItemIndexValue = $inputConfigItemValue[$index]
                            } catch {
                                Write-Verbose "Error accessing index $index for input config item $($inputConfigName): $_"
                                if($index -eq 0) {
                                    Write-Error "At least one value is required for input config item $($inputConfigName)."
                                    throw "At least one value is required for input config item $($inputConfigName)."
                                }
                            }

                            if($null -ne $inputConfigItemIndexValue) {
                                $configurationValue.Value.Value = $inputConfigItemIndexValue
                                continue
                            } else {
                                Write-Verbose "Input config item $($inputConfigName) with index $index is null."
                                if($index -eq 0) {
                                    Write-Error "At least one value is required for input config item $($inputConfigName)."
                                    throw "At least one value is required for input config item $($inputConfigName)."
                                }
                            }
                        }
                    } else {
                        # Handle string index for maps
                        Write-Verbose "Handling string index for map"

                        try{
                            $mapItem = $inputConfigItemValue.PsObject.Properties | Where-Object { $_.Name -eq $indexString }
                        } catch {
                            Write-Verbose "Error accessing map item $indexString for input config item $($inputConfigName): $_"
                            Write-Error "At least one value is required for input config item $($inputConfigName)."
                            throw "At least one value is required for input config item $($inputConfigName)."
                        }
                        if($null -ne $mapItem) {
                            $inputConfigItemIndexValue = $mapItem.Value
                            if($null -ne $inputConfigItemIndexValue) {
                                $configurationValue.Value.Value = $inputConfigItemIndexValue
                                continue
                            } else {
                                Write-Verbose "Input config item $($inputConfigName) with index $indexString is null."
                                Write-Error "At least one value is required for input config item $($inputConfigName)."
                                throw "At least one value is required for input config item $($inputConfigName)."
                            }
                        } else {
                            Write-Verbose "Input config item $($inputConfigName) does not have an index of $indexString."
                            Write-Error "At least one value is required for input config item $($inputConfigName)."
                            throw "At least one value is required for input config item $($inputConfigName)."
                        }
                    }
                } else {
                    Write-Error "Input config item $($inputConfigName) not found."
                    throw "Input config item $($inputConfigName) not found."
                }
            }

            # Look for input config match
            $inputConfigItem = $inputConfig.PsObject.Properties | Where-Object { $_.Name -eq $inputConfigName }
            if($null -ne $inputConfigItem) {
                $configurationValue.Value.Value = $inputConfigItem.Value.Value
                continue
            }

            # Use the default value if no input config is supplied
            if($configurationValue.Value.PSObject.Properties.Name -match "DefaultValue") {
                Write-Verbose "Input not supplied, so using default value of $($configurationValue.Value.DefaultValue) for $($configurationValue.Name)"
                $configurationValue.Value.Value = $configurationValue.Value.DefaultValue
                continue
            }

            Write-ToConsoleLog "Input not supplied, and no default for $($configurationValue.Name)..." -IsError
            throw "Input not supplied, and no default for $($configurationValue.Name)..."
        }

        return $configurationParameters
    }
}
