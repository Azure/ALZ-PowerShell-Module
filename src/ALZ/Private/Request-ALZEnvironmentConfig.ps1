
function Request-ALZEnvironmentConfig {
    param(
        [Parameter(Mandatory = $true)]
        [object] $configurationParameters,
        [Parameter(Mandatory = $false)]
        [switch] $respectOrdering,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $userInputOverrides = $null,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $userInputDefaultOverrides = $null,
        [Parameter(Mandatory = $false)]
        [System.Boolean] $treatEmptyDefaultAsValid = $false,
        [Parameter(Mandatory = $false)]
        [switch] $autoApprove,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $computedInputs = $null

    )
    <#
    .SYNOPSIS
    This function uses a template configuration to prompt for and return a user specified/modified configuration object.
    .EXAMPLE
    Request-ALZEnvironmentConfig
    .EXAMPLE
    Request-ALZEnvironmentConfig -alzIacProvider "bicep"
    .OUTPUTS
    System.Object. The resultant configuration values.
    #>

    $configurations = $configurationParameters.PsObject.Properties

    $hasInputOverrides = $false
    if($userInputOverrides -ne $null) {
        $hasInputOverrides = $true
    }

    $hasDefaultOverrides = $false
    if($userInputDefaultOverrides -ne $null) {
        $hasDefaultOverrides = $true
        $useDefaults = ""
        if($hasInputOverrides) {
            Write-InformationColored "We found you have cached values from a previous run, but have also supplied inputs." -ForegroundColor Yellow -InformationAction Continue
            if($autoApprove) {
                $useDefaults = "skip"
            } else {
                $useDefaults = Read-Host "Would you like to the cached values or use the inputs you have supplied intead? Enter 'use' to use the cached value or just hit 'enter' to use your inputs. (use/skip)"
            }
            if($useDefaults.ToLower() -eq "use") {
                $userInputOverrides = $userInputDefaultOverrides
            }
        } else {
            Write-InformationColored "We found you have cached values from a previous run." -ForegroundColor Yellow -InformationAction Continue
            if($autoApprove) {
                $useDefaults = "use"
            } else {
                $useDefaults = Read-Host "Would you like to use these values or see each of them to validate and change them? Enter 'use' to use the cached value or just hit 'enter' to see and validate each value. (use/verify)"
            }
        }
        if($useDefaults.ToLower() -eq "use") {
            $userInputOverrides = $userInputDefaultOverrides
        }
    }

    if($respectOrdering) {
        $configurations = $configurationParameters.PSObject.Properties | Sort-Object { $_.Value.Order }
    }

    if($null -ne $computedInputs) {
        Write-Verbose $computedInputs
    }
    foreach ($configurationValue in $configurations) {
        $computedInput = $null
        if($null -ne $computedInputs) {
            $computedInput = $computedInputs.PsObject.Properties | Where-Object { $_.Name -eq $configurationValue.Name }
        }

        if($null -ne $computedInput) {
            $configurationValue.Value.Value = $computedInput.Value.Value
            continue
        }

        if ($configurationValue.Value.Type -eq "UserInput") {

            # Check for and add cached as default
            if($hasDefaultOverrides) {
                $defaultOverride = $userInputDefaultOverrides.PsObject.Properties | Where-Object { $_.Name -eq $configurationValue.Name }
                if($null -ne $defaultOverride) {
                    if(!($configurationValue.Value.PSObject.Properties.Name -match "DefaultValue")) {
                        $configurationValue.Value | Add-Member -NotePropertyName "DefaultValue" -NotePropertyValue $defaultOverride.Value
                    } else {
                        $configurationValue.Value.DefaultValue = $defaultOverride.Value
                    }
                }
            }

            # Check for and use override
            if($hasInputOverrides) {
                $userInputOverride = $userInputOverrides.PsObject.Properties | Where-Object { $_.Name -eq $configurationValue.Name }
                if($null -ne $userInputOverride) {
                    $configurationValue.Value.Value = $userInputOverride.Value
                } else {
                    Request-ConfigurationValue -configName $configurationValue.Name -configValue $configurationValue.Value -treatEmptyDefaultAsValid $treatEmptyDefaultAsValid
                }
            } else {
                Request-ConfigurationValue -configName $configurationValue.Name -configValue $configurationValue.Value -treatEmptyDefaultAsValid $treatEmptyDefaultAsValid
            }
        }
    }

    return $configurationParameters
}