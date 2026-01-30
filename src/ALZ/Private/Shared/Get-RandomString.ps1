function Get-RandomString {
    <#
    .SYNOPSIS
        Generates a random alphanumeric string.

    .DESCRIPTION
        This function generates a random string of specified length using uppercase letters,
        lowercase letters, and digits. Useful for generating confirmation codes and unique identifiers.

    .PARAMETER Length
        The length of the random string to generate. Defaults to 8.

    .EXAMPLE
        Get-RandomString
        Returns a random 8-character string.

    .EXAMPLE
        Get-RandomString -Length 12
        Returns a random 12-character string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false)]
        [int]$Length = 8
    )

    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $string = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $string
}
