function Read-MenuSelection {
    <#
    .SYNOPSIS
    Displays a menu of options and prompts the user to select one.
    .DESCRIPTION
    This function displays a numbered list of options and prompts the user to select one.
    It validates the selection and returns the selected option value or the value property if objects are provided.
    .PARAMETER Title
    The title/prompt to display before the menu options. If null/empty, no title is shown.
    .PARAMETER HelpText
    An array of help text lines to display after the title.
    .PARAMETER OptionsTitle
    Optional line of text to render before the options list.
    .PARAMETER Options
    An array of option values to display. Can be simple strings/values, or objects with 'label' and 'value' properties.
    When objects with label/value are provided, the label is displayed and the value is returned.
    .PARAMETER DefaultIndex
    The zero-based index of the default option (default: 0).
    .PARAMETER DefaultValue
    Alternative to DefaultIndex - specify the default value directly. If both are provided, DefaultValue takes precedence.
    .PARAMETER AllowManualEntry
    When set, adds an option [0] to allow manual entry.
    .PARAMETER ManualEntryPrompt
    The prompt to display when manual entry is selected (default: "Enter value").
    .PARAMETER ManualEntryValidator
    A script block that validates manual entry input. Should return $true if valid, $false otherwise.
    The input value is passed as $args[0].
    .PARAMETER ManualEntryErrorMessage
    The error message to display when manual entry validation fails.
    .PARAMETER IsRequired
    When set, the user must provide a value (cannot be empty).
    .PARAMETER RequiredMessage
    The error message to display when a required field is left empty.
    .PARAMETER EmptyMessage
    Message to display when the options array is empty. If set and options are empty, shows this message and falls back to manual entry.
    .PARAMETER Type
    The expected data type for validation: 'string' (default), 'number', 'guid', 'boolean', or 'array'.
    When AllowManualEntry is used, input will be validated against this type.
    For 'array', comma-separated input is parsed into an array.
    .PARAMETER IsSensitive
    When set, input is read securely using Read-Host -AsSecureString and the value is masked in display.
    .OUTPUTS
    Returns the selected option value.
    .EXAMPLE
    $selection = Read-MenuSelection -Title "Select IaC type:" -Options @("terraform", "bicep") -DefaultIndex 0
    .EXAMPLE
    $subscriptions = @(
        @{ label = "Subscription 1 (sub-id-1)"; value = "sub-id-1" },
        @{ label = "Subscription 2 (sub-id-2)"; value = "sub-id-2" }
    )
    $selection = Read-MenuSelection -Title "Select subscription:" -Options $subscriptions -AllowManualEntry -ManualEntryPrompt "Enter subscription ID"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $Title,

        [Parameter(Mandatory = $false)]
        [string[]] $HelpText = @(),

        [Parameter(Mandatory = $false)]
        [string] $OptionsTitle = $null,

        [Parameter(Mandatory = $false)]
        [array] $Options = @(),

        [Parameter(Mandatory = $false)]
        [int] $DefaultIndex = 0,

        [Parameter(Mandatory = $false)]
        $DefaultValue = $null,

        [Parameter(Mandatory = $false)]
        [switch] $AllowManualEntry,

        [Parameter(Mandatory = $false)]
        [string] $ManualEntryPrompt = "Enter value",

        [Parameter(Mandatory = $false)]
        [scriptblock] $ManualEntryValidator = $null,

        [Parameter(Mandatory = $false)]
        [string] $ManualEntryErrorMessage = "Invalid input. Please try again.",

        [Parameter(Mandatory = $false)]
        [switch] $IsRequired,

        [Parameter(Mandatory = $false)]
        [string] $RequiredMessage = "This field is required. Please enter a value.",

        [Parameter(Mandatory = $false)]
        [string] $EmptyMessage = $null,

        [Parameter(Mandatory = $false)]
        [ValidateSet("string", "number", "guid", "boolean", "array")]
        [string] $Type = "string",

        [Parameter(Mandatory = $false)]
        [switch] $IsSensitive
    )

    # Built-in type validators
    $typeValidators = @{
        "guid"    = {
            param($value)
            return $value -match "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        }
        "number"  = {
            param($value)
            $intResult = 0
            return [int]::TryParse($value, [ref]$intResult)
        }
        "boolean" = {
            param($value)
            $validBooleans = @('true', 'false', 'yes', 'no', '1', '0', 'y', 'n', 't', 'f')
            return $validBooleans -contains $value.ToString().ToLower()
        }
        "string"  = {
            param($value)
            return $true
        }
        "array"   = {
            param($value)
            return $true  # Arrays are always valid as input
        }
    }

    $typeErrorMessages = @{
        "guid"    = "Invalid GUID format. Please enter a valid GUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)"
        "number"  = "Invalid format. Please enter an integer number."
        "boolean" = "Invalid format. Please enter true or false."
        "string"  = "Invalid input."
        "array"   = "Invalid input."
    }

    # Function to convert value to appropriate type
    function ConvertTo-TypedValue {
        param($Value, $TargetType, $DefaultValue = $null)
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $DefaultValue
        }
        switch ($TargetType) {
            "number" {
                $intResult = 0
                if ([int]::TryParse($Value, [ref]$intResult)) {
                    return $intResult
                }
                return $Value
            }
            "boolean" {
                $valueStr = $Value.ToString().ToLower()
                return $valueStr -in @('true', 'yes', '1', 'y', 't')
            }
            "array" {
                # Parse comma-separated values into an array
                return @($Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
            default {
                return $Value
            }
        }
    }

    # Get the effective validator - use ManualEntryValidator if provided, otherwise use type validator
    $effectiveValidator = if ($null -ne $ManualEntryValidator) {
        $ManualEntryValidator
    } elseif ($Type -ne "string") {
        $typeValidators[$Type]
    } else {
        $null
    }

    # Get the effective error message
    $effectiveErrorMessage = if (-not [string]::IsNullOrWhiteSpace($ManualEntryErrorMessage) -and $ManualEntryErrorMessage -ne "Invalid input. Please try again.") {
        $ManualEntryErrorMessage
    } elseif ($Type -ne "string") {
        $typeErrorMessages[$Type]
    } else {
        $ManualEntryErrorMessage
    }

    # Helper function to read input (handles sensitive vs normal input)
    function Read-InputValue {
        param($Prompt, $Sensitive)
        if ($Sensitive) {
            $secureValue = Read-Host $Prompt -AsSecureString
            return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
            )
        } else {
            return Read-Host $Prompt
        }
    }

    # Helper function to mask sensitive values
    function Get-MaskedValue {
        param($Value)
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return "(empty)"
        }
        $valueStr = $Value.ToString()
        if ($valueStr.Length -ge 8) {
            return $valueStr.Substring(0, 3) + "***" + $valueStr.Substring($valueStr.Length - 3)
        } else {
            return "********"
        }
    }

    # Helper function to get the value from an option (handles both simple values and label/value objects)
    function Get-OptionValue {
        param($Option)
        if ($Option -is [hashtable] -and $Option.ContainsKey('value')) {
            return $Option.value
        } elseif ($Option -is [PSCustomObject] -and $null -ne $Option.PSObject.Properties['value']) {
            return $Option.value
        }
        return $Option
    }

    # Helper function to get the label from an option
    function Get-OptionLabel {
        param($Option)
        if ($Option -is [hashtable] -and $Option.ContainsKey('label')) {
            return $Option.label
        } elseif ($Option -is [PSCustomObject] -and $null -ne $Option.PSObject.Properties['label']) {
            return $Option.label
        }
        return $Option.ToString()
    }

    # Determine if we have options to display
    $hasOptions = $null -ne $Options -and $Options.Count -gt 0

    # If DefaultValue is provided and we have options, find its index
    if ($null -ne $DefaultValue -and $hasOptions) {
        for ($i = 0; $i -lt $Options.Count; $i++) {
            if ((Get-OptionValue -Option $Options[$i]) -eq $DefaultValue) {
                $DefaultIndex = $i
                break
            }
        }
    }

    # Display title if provided
    if (-not [string]::IsNullOrWhiteSpace($Title)) {
        Write-ToConsoleLog $Title -IsPrompt
    }

    # Display help text if provided
    foreach ($helpLine in $HelpText) {
        if (-not [string]::IsNullOrWhiteSpace($helpLine)) {
            Write-ToConsoleLog $helpLine -IsSelection
        }
    }

    # Display default value and required status
    if ($null -ne $DefaultValue -and -not [string]::IsNullOrWhiteSpace($DefaultValue)) {
        $displayDefault = if ($IsSensitive.IsPresent) { Get-MaskedValue -Value $DefaultValue } else { $DefaultValue }
        Write-ToConsoleLog "Default: $displayDefault" -Color Cyan -IsSelection
    }
    if ($IsRequired.IsPresent) {
        Write-ToConsoleLog "Required: Yes" -Color Yellow -IsSelection
    }

    # If no options, go directly to manual entry
    if (-not $hasOptions) {
        if (-not [string]::IsNullOrWhiteSpace($EmptyMessage)) {
            Write-ToConsoleLog $EmptyMessage -IsWarning
        }

        $result = $null
        do {
            $manualInput = Read-InputValue -Prompt $ManualEntryPrompt -Sensitive $IsSensitive.IsPresent
            if ([string]::IsNullOrWhiteSpace($manualInput)) {
                # For arrays, return empty array or default; for others return default
                if ($Type -eq "array") {
                    if ($null -ne $DefaultValue -and $DefaultValue -is [System.Collections.IList]) {
                        $result = $DefaultValue
                    } else {
                        $result = @()
                    }
                } elseif ($null -ne $DefaultValue -and -not [string]::IsNullOrWhiteSpace($DefaultValue)) {
                    $result = ConvertTo-TypedValue -Value $DefaultValue -TargetType $Type
                }
            } else {
                # Validate and convert
                if ($null -ne $effectiveValidator -and -not [string]::IsNullOrWhiteSpace($manualInput)) {
                    if (-not (& $effectiveValidator $manualInput)) {
                        Write-ToConsoleLog $effectiveErrorMessage -IsError
                        $result = $null
                        continue
                    }
                }
                $result = ConvertTo-TypedValue -Value $manualInput -TargetType $Type -DefaultValue $DefaultValue
            }
            # Check required - for arrays, check if empty
            if ($IsRequired.IsPresent) {
                if ($Type -eq "array") {
                    if ($null -eq $result -or $result.Count -eq 0) {
                        Write-ToConsoleLog $RequiredMessage -IsError
                        $result = $null
                    }
                } elseif ([string]::IsNullOrWhiteSpace($result)) {
                    Write-ToConsoleLog $RequiredMessage -IsError
                    $result = $null
                }
            }
        } while ($IsRequired.IsPresent -and $null -eq $result)
        return $result
    }

    # Display options title if provided
    if (-not [string]::IsNullOrWhiteSpace($OptionsTitle)) {
        Write-ToConsoleLog $OptionsTitle -IsSelection
    }

    # Display options
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $option = $Options[$i]
        $label = Get-OptionLabel -Option $option
        $value = Get-OptionValue -Option $option
        $isCurrent = ($null -ne $DefaultValue -and $value -eq $DefaultValue) -or ($null -eq $DefaultValue -and $i -eq $DefaultIndex)
        $currentMarker = if ($isCurrent) { " (current)" } else { "" }

        if ($isCurrent) {
            Write-ToConsoleLog "[$($i + 1)] $label$currentMarker" -IsSelection -Color Green -IndentLevel 1
        } else {
            Write-ToConsoleLog "[$($i + 1)] $label" -IsSelection -IndentLevel 1
        }
    }

    # Show manual entry option if allowed
    if ($AllowManualEntry.IsPresent) {
        Write-ToConsoleLog "[0] Enter manually" -IsSelection -IndentLevel 1
    }

    # Build prompt text
    $promptText = "Enter selection (1-$($Options.Count)"
    if ($AllowManualEntry.IsPresent) {
        $promptText += ", 0 for manual entry"
    }
    $promptText += ", default: $($DefaultIndex + 1))"

    # Get selection
    $result = $null
    do {
        $selection = Read-InputValue -Prompt $promptText -Sensitive $IsSensitive.IsPresent

        if ([string]::IsNullOrWhiteSpace($selection)) {
            # Use default
            $result = Get-OptionValue -Option $Options[$DefaultIndex]
        } elseif ($AllowManualEntry.IsPresent -and $selection -eq "0") {
            # Manual entry
            do {

                $manualInput = Read-InputValue -Prompt $ManualEntryPrompt -Sensitive $IsSensitive.IsPresent
                if ([string]::IsNullOrWhiteSpace($manualInput) -and -not [string]::IsNullOrWhiteSpace($DefaultValue)) {
                    $result = $DefaultValue
                    break
                }
                if ($null -ne $effectiveValidator -and -not [string]::IsNullOrWhiteSpace($manualInput)) {
                    if (-not (& $effectiveValidator $manualInput)) {
                        Write-ToConsoleLog $effectiveErrorMessage -IsError
                        continue
                    }
                }
                $result = ConvertTo-TypedValue -Value $manualInput -TargetType $Type
                break
            } while ($true)
        } else {
            $selectedIndex = [int]$selection - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $Options.Count) {
                $result = Get-OptionValue -Option $Options[$selectedIndex]
            } else {
                Write-ToConsoleLog "Invalid selection, please try again." -IsWarning
                continue
            }
        }

        # Check required
        if ($IsRequired.IsPresent -and [string]::IsNullOrWhiteSpace($result)) {
            Write-ToConsoleLog $RequiredMessage -IsError
            $result = $null
        }
    } while ($null -eq $result -and $IsRequired.IsPresent)

    return $result
}
