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
    if ($gitInit -ieq "y" -and $PSCmdlet.ShouldProcess("gitrepository", "initialize")) {
        if ((git config --get init.defaultbranch) -eq "master") {
            git init -b main $alzEnvironmentDestination
            return $true
        } else {
            git init $alzEnvironmentDestination
            return $true
        }
    }
    return $false
}
