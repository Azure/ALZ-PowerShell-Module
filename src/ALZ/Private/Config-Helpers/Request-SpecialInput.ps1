function Request-SpecialInput {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $type,

        [Parameter(Mandatory = $false)]
        [string] $starterPath,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $bootstrapModules,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $userInputOverrides = $null
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {

        $result = ""

        if($null -ne $userInputOverrides) {
            $userInputOverride = $userInputOverrides.PSObject.Properties | Where-Object { $_.Name -eq $type }
            if($null -ne $userInputOverride) {
                $result = $userInputOverride.Value
                return $result
            }
        }

        $gotValidInput = $false

        while(!$gotValidInput) {
            if($type -eq "starter") {

                $starterFolders = Get-ChildItem -Path $starterPath -Directory
                Write-InformationColored "Please select the starter module you would like to use, you can enter one of the following keys:" -ForegroundColor Yellow -InformationAction Continue

                $starterOptions = @()
                foreach($starterFolder in $starterFolders) {
                    if($starterFolder.Name -eq $starterPipelineFolder) {
                        continue
                    }

                    Write-InformationColored "- $($starterFolder.Name)" -ForegroundColor Yellow -InformationAction Continue
                    $starterOptions += $starterFolder.Name
                }

                Write-InformationColored ": " -ForegroundColor Yellow -NoNewline -InformationAction Continue
                $result = Read-Host

                if($result -notin $starterOptions) {
                    Write-InformationColored "The starter '$result' that you have selected does not exist. Please try again with a valid starter..." -ForegroundColor Red -InformationAction Continue
                } else {
                    $gotValidInput = $true
                }
            }

            if($type -eq "iac") {
                Write-InformationColored "Please select the IAC you would like to use, you can enter one of 'bicep or 'terraform': " -ForegroundColor Yellow -NoNewline -InformationAction Continue
                $result = Read-Host

                $validIac = @("bicep", "terraform")
                if($result -notin $validIac) {
                    Write-InformationColored "The IAC '$result' that you have selected does not exist. Please try again with a valid IAC..." -ForegroundColor Red -InformationAction Continue

                } else {
                    $gotValidInput = $true
                }
            }

            if($type -eq "bootstrap") {
                Write-InformationColored "Please select the bootstrap module you would like to use, you can enter one of the following keys:" -ForegroundColor Yellow -InformationAction Continue

                $bootstrapOptions = @()
                if($bootstrapModules.PsObject.Properties.Name.Count -eq 0) {
                    $bootstrapOptions += "azuredevops"
                    Write-InformationColored "- azuredevops" -ForegroundColor Yellow -InformationAction Continue
                    $bootstrapOptions += "github"
                    Write-InformationColored "- github" -ForegroundColor Yellow -InformationAction Continue
                } else {
                    foreach ($bootstrapModule in $bootstrapModules.PsObject.Properties) {
                        Write-InformationColored "- $($bootstrapModule.Name) ($($bootstrapModule.Value.description))" -ForegroundColor Yellow -InformationAction Continue
                        $bootstrapOptions += $bootstrapModule.Name
                    }
                }

                Write-InformationColored ": " -ForegroundColor Yellow -NoNewline -InformationAction Continue
                $result = Read-Host

                if($result -notin $bootstrapOptions) {
                    Write-InformationColored "The starter '$result' that you have selected does not exist. Please try again with a valid starter..." -ForegroundColor Red -InformationAction Continue
                } else {
                    $gotValidInput = $true
                }
            }
        }

        return $result
    }
}