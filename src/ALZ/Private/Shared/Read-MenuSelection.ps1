function Read-MenuSelection {
    <#
    .SYNOPSIS
    Displays a menu of options and prompts the user to select one.
    .DESCRIPTION
    This function displays a numbered list of options and prompts the user to select one.
    It validates the selection and returns the selected option value.
    .PARAMETER Title
    The title/prompt to display before the menu options.
    .PARAMETER Options
    An array of option values to display.
    .PARAMETER DefaultIndex
    The zero-based index of the default option (default: 0).
    .PARAMETER OptionDescriptions
    Optional descriptions for options. Can be either:
    - A hashtable mapping option values to descriptions
    - An array of descriptions matching the Options array by index
    .OUTPUTS
    Returns the selected option value.
    .EXAMPLE
    $selection = Read-MenuSelection -Title "Select IaC type:" -Options @("terraform", "bicep") -DefaultIndex 0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [array] $Options,

        [Parameter(Mandatory = $false)]
        [int] $DefaultIndex = 0,

        [Parameter(Mandatory = $false)]
        $OptionDescriptions = $null
    )

    Write-InformationColored $Title -ForegroundColor Yellow -InformationAction Continue

    for ($i = 0; $i -lt $Options.Count; $i++) {
        $option = $Options[$i]
        $default = if ($i -eq $DefaultIndex) { " (Default)" } else { "" }

        # Get description based on whether it's a hashtable or array
        $description = ""
        if ($null -ne $OptionDescriptions) {
            if ($OptionDescriptions -is [hashtable] -and $OptionDescriptions.ContainsKey($option)) {
                $description = " - $($OptionDescriptions[$option])"
            } elseif ($OptionDescriptions -is [array] -and $i -lt $OptionDescriptions.Count) {
                $description = " - $($OptionDescriptions[$i])"
            }
        }

        Write-InformationColored "  [$($i + 1)] $option$description$default" -ForegroundColor White -InformationAction Continue
    }

    do {
        $selection = Read-Host "Enter selection (1-$($Options.Count), default: $($DefaultIndex + 1))"
        if ([string]::IsNullOrWhiteSpace($selection)) {
            $selectedIndex = $DefaultIndex
        } else {
            $selectedIndex = [int]$selection - 1
        }
    } while ($selectedIndex -lt 0 -or $selectedIndex -ge $Options.Count)

    return $Options[$selectedIndex]
}
