# discover all ps1 file(s) in Public and Private paths
Write-Verbose "Discovering Public & Private src."

$itemSplat = @{
    Filter      = '*.ps1'
    Recurse     = $true
    ErrorAction = 'Stop'
}
try {
    $public = @(Get-ChildItem -Path "$PSScriptRoot\Public" @itemSplat)
    Write-Verbose "Found $($public.Count) Public file(s)."
    $private = @(Get-ChildItem -Path "$PSScriptRoot\Private" @itemSplat)
} catch {
    Write-Error $_
    throw "Unable to get get file information from Public & Private src."
}

# dot source all .ps1 file(s) found
foreach ($file in @($public + $private)) {
    Write-Verbose "Dot sourcing [$($file.FullName)]"
    try {
        . $file.FullName
    } catch {
        throw "Unable to dot source [$($file.FullName)]"

    }
}


# export all public functions
Export-ModuleMember -Function $public.Basename