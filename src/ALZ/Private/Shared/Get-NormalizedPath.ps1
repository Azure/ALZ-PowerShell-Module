function Get-NormalizedPath {
    <#
    .SYNOPSIS
    Normalizes a file path, expanding home directory shortcuts.
    .DESCRIPTION
    This function normalizes a path by expanding the ~/ shortcut to the user's home directory.
    .PARAMETER Path
    The path to normalize.
    .OUTPUTS
    Returns the normalized path string.
    .EXAMPLE
    $normalizedPath = Get-NormalizedPath -Path "~/accelerator"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if ($Path.StartsWith("~/")) {
        return Join-Path $HOME $Path.Replace("~/", "")
    }

    return $Path
}
