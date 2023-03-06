$alzBicepModulesRoot = "/infra-as-code/bicep/modules"

function Edit-ALZConfigurationFilesInPlace {
    param(
        [Parameter(Mandatory = $true)]
        [string] $alzBicepRoot,

        [Parameter(Mandatory = $true)]
        [object] $configuration
    )

    # Temporary location to the bicep modules and by extension configuration.
    $bicepModules = Join-Path $alzBicepRoot $alzBicepModulesRoot

    $files = @(Get-ChildItem -Path $bicepModules -Recurse -Filter *.parameters.*.json)

    foreach ($file in $files) {
        $bicepConfiguration = Get-Content $file | ConvertFrom-Json -AsHashtable
        $modified = $false

        foreach ($configurationObject in $configuration) {
            foreach ($name in $configurationObject.names) {
                if ($null -ne $bicepConfiguration.parameters[$name]) {
                    $bicepConfiguration.parameters[$name].value = $configurationObject.value
                    $modified = $true
                }
            }
        }

        if ($true -eq $modified) {
            Write-InformationColored $file.FullName -ForegroundColor Yellow -InformationAction Continue
            $bicepConfiguration | ConvertTo-Json -Depth 10  | Out-File $file.FullName
        }
    }
}


function Initialize-ConfigurationObject {

    return @(
        @{
            description  = "The prefix that will be added to all resources created by this deployment."
            names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
            value        = "alz"
            defaultValue = "alz"
        },
        @{
            description  = "The suffix that will be added to all resources created by this deployment."
            names        = @("parTopLevelManagementGroupSuffix")
            value        = ""
            defaultValue = ""
        },
        @{
            description   = "Deployment location."
            name          = @("parLocation")
            allowedValues = @(Get-AzLocation | Select-Object -ExpandProperty Location | Sort-Object Location)
            value         = ""
        }
    )
}

function Request-ConfigurationValue {
    param(
        [Parameter(Mandatory = $true)]
        [object] $configValue
    )

    $allowedValues = $configValue.allowedValues
    $hasAllowedValues = $null -ne $configValue.allowedValues

    $defaultValue = $configValue.defaultValue
    $hasDefaultValue = $null -ne $configValue.defaultValue

    Write-InformationColored $configValue.description -ForegroundColor White -InformationAction Continue
    if ($hasAllowedValues) {
        Write-InformationColored "[allowed: $allowedValues] " -ForegroundColor Yellow -InformationAction Continue
    }

    do {
        Write-InformationColored "$($configValue.name) " -ForegroundColor Yellow -NoNewline -InformationAction Continue
        if ($hasDefaultValue) {
            $displayDefaultValue = $defaultValue -eq "" ? "''" : $defaultValue
            Write-InformationColored "(default: ${displayDefaultValue}): " -ForegroundColor Yellow -NoNewline -InformationAction Continue
        } else {
            Write-InformationColored ": " -NoNewline -InformationAction Continue
        }

        $readValue = Read-Host

        if ($hasDefaultValue -and $readValue -eq "") {
            $configValue.value = $configValue.defaultValue
        } else {
            $configValue.value = $readValue
        }
    }
    while ((($null -eq $configValue.value -or "" -eq $configValue.value) -and ($configValue.value -ne $configValue.defaultValue)) -or ($hasAllowedValues -and $allowedValues.Contains($configValue.value) -eq $false))

    Write-Information "" -InformationAction Continue
}

function Request-CreateSubscriptionPreference {
    $title = "Create Subscriptions"
    $message = "Do you want the script to create 3 NEW subscriptions to be used by Cloud for Sovereign?"

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "Creates 3 subscriptions ()."

    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "Specify existing subscription(s) instead."

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice($title, $message, $options, 0)

    switch ($result) {
        0 { return $true }
        1 { return $false }
    }
}

function Request-ALZEnvironmentConfig {
    param(
    )
    <#
    .SYNOPSIS
    This function uses a template configuration to prompt for and return a user specified/modified configuration object.
    .EXAMPLE
    New-SlzEnvironmentConfig
    .EXAMPLE
    New-SlzEnvironmentConfig -sourceConfigurationFile "orchestration/scripts/parameters/sovereignLandingZone.parameters.json"
    .OUTPUTS
    System.Object. The resultant configuration values.
    #>
    $configuration = Initialize-ConfigurationObject

    foreach ($configurationValue in $configuration) {
        Request-ConfigurationValue $configurationValue
    }

    return $configuration
}