function Test-ALZGitRepository {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination
    )
    $gitDirectory = Join-Path $alzEnvironmentDestination ".git"
    if (Test-Path $gitDirectory) {
        Write-Verbose "The directory $alzEnvironmentDestination is already a git repository."
        return $true
    }
    $gitInit = Read-Host "Initialize the directory $alzEnvironmentDestination as a git repository? (y/n)"
    if (($gitInit -eq "y" -or $gitInit -eq "Y")  -and $PSCmdlet.ShouldProcess("gitrepository", "initialize")) {
        git init $alzEnvironmentDestination
        return $true
    }
    return $false
}