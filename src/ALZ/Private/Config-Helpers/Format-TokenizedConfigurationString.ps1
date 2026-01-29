function Format-TokenizedConfigurationString {
    param(
        [AllowEmptyString()]
        [Parameter(Mandatory = $true)]
        [string] $tokenizedString,

        [Parameter(Mandatory = $true)]
        [object] $configuration
    )
    $values = $tokenizedString -split "\{\%|\%\}"

    $returnValue = ""
    foreach ($value in $values) {
        $isToken = $tokenizedString -contains "{%$value%}"
        if ($null -ne $configuration.$value) {
            $returnValue += $configuration.$value.Value
        } elseif (($null -eq $configuration.$value) -and $isToken) {
            Write-ToConsoleLog "Specified replacement token '${value}' not found in configuration." -IsWarning
            $returnValue += "{%$value%}"
        } else {
            $returnValue += $value
        }
    }

    return $returnValue
}
