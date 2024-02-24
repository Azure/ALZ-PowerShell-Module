function Request-SpecialInput {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $type,

        [Parameter(Mandatory = $false)]
        [string] $starterPath,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $bootstrapModules
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {

        $result = ""

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
                throw
            }
        }

        if($type -eq "iac") {
            Write-InformationColored "Please select the IAC you would like to use, you can enter one of 'bicep or 'terraform': " -ForegroundColor Yellow -NoNewline -InformationAction Continue
            $result = Read-Host

            $validIac = @("bicep", "terraform")
            if($result -notin $validIac) {
                Write-InformationColored "The IAC '$result' that you have selected does not exist. Please try again with a valid IAC..." -ForegroundColor Red -InformationAction Continue
                throw
            }
        }

        if($type -eq "bootstrap") {
            Write-InformationColored "Please select the bootstrap module you would like to use, you can enter one of the following keys:" -ForegroundColor Yellow -InformationAction Continue
            foreach ($bootstrapModule in $bootstrapModules.PsObject.Properties) {
                Write-InformationColored "- $($bootstrapModule.Name) ($($bootstrapModule.Value.description))" -ForegroundColor Yellow -InformationAction Continue
            }
            Write-InformationColored ": " -ForegroundColor Yellow -NoNewline -InformationAction Continue
            $result = Read-Host
        }

        return $result
    }
}