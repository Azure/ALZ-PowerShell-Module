function Request-SpecialInput {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $type,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $starterConfig,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $bootstrapModules,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $userInputOverrides = $null
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

        if($null -ne $userInputOverrides) {
            $userInputOverride = $userInputOverrides.PSObject.Properties | Where-Object { $_.Name -eq $type }
            if($null -ne $userInputOverride) {
                $result = $userInputOverride.Value
                if($options.key -notcontains $result -and $aliasOptions.key -notcontains $result) {
                    Write-InformationColored "The $typeDescription '$result' that you have selected does not exist. Please try again with a valid $typeDescription..." -ForegroundColor Red -InformationAction Continue
                    throw "The $typeDescription '$result' that you have selected does not exist. Please try again with a valid $typeDescription..."
                }
                return $result
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
