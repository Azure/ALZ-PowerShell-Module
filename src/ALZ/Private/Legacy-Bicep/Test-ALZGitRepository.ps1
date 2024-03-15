function Test-ALZGitRepository {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("Output")]
        [Alias("OutputDirectory")]
        [Alias("O")]
        [string] $alzEnvironmentDestination,
        [Parameter(Mandatory = $false)]
        [switch] $autoApprove
    )
    $gitDirectory = Join-Path $alzEnvironmentDestination ".git"
    if (Test-Path $gitDirectory) {
        Write-Verbose "The directory $alzEnvironmentDestination is already a git repository."
        return $true
    }

    $runGitInit = $true
    $gitBranch = "main"

    if(!$autoApprove) {
        $gitInit = Read-Host "Initialize the directory $alzEnvironmentDestination as a git repository? (y/n)"
        if ($gitInit -ieq "y") {
            $runGitInit = $true
            $gitBranch = Read-Host "Enter the default branch name. (Hit enter to skip and use 'main')"
            if ($gitBranch -eq "") {
                $gitBranch = "main"
            }
        }
    }

    if($runGitInit -and $PSCmdlet.ShouldProcess("gitrepository", "initialize")) {
        git init -b $gitBranch $alzEnvironmentDestination
    }

    return $runGitInit
}
