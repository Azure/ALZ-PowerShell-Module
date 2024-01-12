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
        $gitBranch = Read-Host "Enter the default branch name. (Hit enter to skip and use 'main')"
        if($gitBranch -eq "") {
          $gitBranch = "main"
        }
        git init -b $gitBranch $alzEnvironmentDestination
        return $true
    }
    return $false
}
