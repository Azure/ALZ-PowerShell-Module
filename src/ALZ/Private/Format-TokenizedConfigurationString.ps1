function Format-TokenizedConfigurationString {
    param(
        [Parameter(Mandatory = $true)]
        [string] $tokenizedString,

        [Parameter(Mandatory = $true)]
        [object] $configuration
    )
    $values = $tokenizedString -split "\{\%|\%\}"

    $returnValue = ""
    foreach ($value in $values) {
        if ($null -ne $configuration.$value) {
            $returnValue += $configuration.$value.Value
        } else {
            $returnValue += $value
        }
    }

    return $returnValue
}