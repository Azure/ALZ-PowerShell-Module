function Request-SpecialInput {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $type,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $starterConfig,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $bootstrapModules
    )

    if ($PSCmdlet.ShouldProcess("ALZ-Terraform module configuration", "modify")) {

        $result = ""
        $options = @()
        $aliasOptions = @()
        $typeDescription = ""

        if($type -eq "iac") {
            $options += @{ key = "bicep"; name = "Bicep"; description = "Bicep" }
            $options += @{ key = "terraform"; name = "Terraform"; description = "Terraform" }
            $typeDescription = "Infrastructure as Code (IaC) language"
        }

        if($type -eq "bootstrap") {
            if($bootstrapModules.PsObject.Properties.Name.Count -eq 0) {
                $options += @{ key = "azuredevops"; name = "Azure DevOps"; description = "Azure DevOps" }
                $options += @{ key = "github"; name = "GitHub"; description = "GitHub" }
                $aliasOptions += @{ key = "alz_azuredevops"; name = "Azure DevOps"; description = "Azure DevOps" }
                $aliasOptions += @{ key = "alz_github"; name = "GitHub"; description = "GitHub" }
            } else {
                foreach ($bootstrapModule in $bootstrapModules.PsObject.Properties) {
                    $options += @{ key = $bootstrapModule.Name; name = $bootstrapModule.Value.short_name; description = $bootstrapModule.Value.description }
                    foreach($alias in $bootstrapModule.Value.aliases) {
                        $aliasOptions += @{ key = $alias; name = $bootstrapModule.Value.short_name; description = $bootstrapModule.Value.description }
                    }
                }
            }
            $typeDescription = "bootstrap module"
        }

        if($type -eq "starter") {
            foreach($starter in $starterConfig.starter_modules.PsObject.Properties) {
                if($starter.Name -eq $starterPipelineFolder) {
                    continue
                }

                $options += @{ key = $starter.Name; name = $starter.Value.short_name; description = $starter.Value.description }
            }
            $typeDescription = "starter module"
        }

        if($type -eq "inputConfigFilePath") {
            $retryCount = 0
            $maxRetryCount = 3

            if($IsWindows) {
                while($retryCount -lt $maxRetryCount) {
                    Add-Type -AssemblyName System.Windows.Forms
                    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
                        InitialDirectory = [Environment]::GetFolderPath("MyComputer")
                        Filter           = "YAML or JSON (*.yml;*.yaml;*.json)|*.yml;*.yaml;*.json"
                        Title            = "Select your input configuration file..."
                        MultiSelect      = $true
                    }

                    if($FileBrowser.ShowDialog() -eq "OK") {
                        $result = $FileBrowser.FileNames
                        Write-Verbose "Selected file(s): $result"
                        return $result
                    } else {
                        $retryCount++
                        Write-InformationColored "You must select a file to continue..." -ForegroundColor Red -InformationAction Continue
                    }
                }
            } else {
                $validPaths = $false
                while(-not $validPath -and $retryCount -lt $maxRetryCount) {
                    $paths = Read-Host "Please enter the paths to your input configuration file. Separate multiple files with a comma..."
                    $result = $paths -split "," | ForEach-Object { $_.Trim() }
                    $validPaths = $true
                    foreach($file in $result) {
                        if(-not (Test-Path $file)) {
                            $validPaths = $false
                            Write-InformationColored "The path '$result' that you have entered does not exist. Please try again with a valid path..." -ForegroundColor Red -InformationAction Continue
                        }
                    }
                    if($validPaths) {
                        return $result
                    } else {
                        $retryCount++
                    }
                }
            }

            if($retryCount -eq $maxRetryCount) {
                Write-InformationColored "You have exceeded the maximum number of retries. Exiting..." -ForegroundColor Red -InformationAction Continue
                throw "You have exceeded the maximum number of retries. Exiting..."
            }
        }

        # Add the options to the choices array
        $choices = @()
        $usedLetters = @()
        foreach($option in $options) {
            $letterIndex = 0

            Write-Verbose "Checking for used letters in '$($option.name)'. Used letters: $usedLetters"
            while($usedLetters -contains $option.name[$letterIndex].ToString().ToLower()) {
                $letterIndex++
            }

            $usedLetters += $option.name[$letterIndex].ToString().ToLower()
            $option.name = $option.name.Insert($letterIndex, "&")
            $choices += New-Object System.Management.Automation.Host.ChoiceDescription $option.name, $option.description
        }

        $message = "Please select the $typeDescription you would like to use."
        $title = "Choose $typeDescription"
        $resultIndex = $host.ui.PromptForChoice($title, $message, $choices, 0)
        $result = $options[$resultIndex].key

        Write-InformationColored "You selected '$result'. Continuing with deployment..." -ForegroundColor Green -InformationAction Continue

        return $result
    }
}
