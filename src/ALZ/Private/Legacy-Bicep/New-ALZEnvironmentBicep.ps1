function New-ALZEnvironmentBicep {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $targetDirectory,

        [Parameter(Mandatory = $false)]
        [string] $upstreamReleaseVersion,

        [Parameter(Mandatory = $false)]
        [string] $upstreamReleaseFolderPath,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $userInputOverrides = $null,

        [Parameter(Mandatory = $false)]
        [ValidateSet("github", "azuredevops")]
        [string] $vcs,

        [Parameter(Mandatory = $false)]
        [switch] $local,

        [Parameter(Mandatory = $false)]
        [switch] $autoApprove
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Bicep module configuration", "modify")) {

        New-ALZDirectoryEnvironment -alzEnvironmentDestination $targetDirectory -alzCicdDestination $vcs | Out-String | Write-Verbose

        # Getting the configuration
        $configFilePath = Join-Path -Path $upstreamReleaseFolderPath -ChildPath "accelerator/.config/ALZ-Powershell.config.json"
        Write-Verbose "Config path: $configFilePath"
        $bicepConfig = Get-ALZConfig -configFilePath $configFilePath

        Write-InformationColored "Copying ALZ-Bicep module to $targetDirectory" -ForegroundColor Green -InformationAction Continue
        Copy-ALZParametersFile -alzEnvironmentDestination $targetDirectory -upstreamReleaseDirectory $upstreamReleaseFolderPath -configFiles $bicepConfig.config_files | Out-String | Write-Verbose
        Copy-ALZParametersFile -alzEnvironmentDestination $targetDirectory -upstreamReleaseDirectory $upstreamReleaseFolderPath -configFiles $bicepConfig.cicd.$vcs | Out-String | Write-Verbose

        $configuration = Request-ALZEnvironmentConfig -configurationParameters $bicepConfig.parameters -userInputOverrides $userInputOverrides -autoApprove:$autoApprove.IsPresent

        Set-ComputedConfiguration -configuration $configuration | Out-String | Write-Verbose
        Edit-ALZConfigurationFilesInPlace -alzEnvironmentDestination $targetDirectory -configuration $configuration | Out-String | Write-Verbose
        Build-ALZDeploymentEnvFile -configuration $configuration -Destination $targetDirectory -version $upstreamReleaseVersion | Out-String | Write-Verbose

        if($local) {
            $isGitRepo = Test-ALZGitRepository -alzEnvironmentDestination $targetDirectory
            if (-not $isGitRepo) {
                Write-InformationColored "The directory $targetDirectory is not a git repository.  Please make sure it is a git repo after initialization." -ForegroundColor Red -InformationAction Continue
            }
        }
    }
}