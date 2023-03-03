function Update-ALZBicepConfigurationFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string] $alzBicepRoot,

        [Parameter(Mandatory = $true)]
        [object] $configuration
    )

    $bicepModules = Join-Path $alzBicepRoot $alzBicepModulesRoot

    $files = @(Get-ChildItem -Path $bicepModules -Recurse -Filter *.parameters.*.json)

    foreach ($file in $files) {
        $bicepConfiguration = Get-Content $file | ConvertFrom-Json -AsHashtable
        $modified = $false

        foreach ($configurationObject in $configuration) {
            if ($null -ne $bicepConfiguration.parameters[$configurationObject.name]) {
                $bicepConfiguration.parameters[$configurationObject.name].value = $configurationObject.value
                $modified = $true
            }
        }

        if ($true -eq $modified) {
            Write-Host $file.FullName
            $bicepConfiguration | ConvertTo-Json -Depth 10  | Out-File $file.FullName
        }
    }
}


function Initialize-ConfigurationObject {

    return @(
        @{
            description  = "The prefix that will be added to all resources created by this deployment."
            name         = "parTopLevelManagementGroupPrefix"
            value        = "alz"
            defaultValue = "alz"
        },
        @{
            description  = "The suffix that will be added to all resources created by this deployment."
            name         = "parTopLevelManagementGroupSuffix"
            value        = ""
            defaultValue = ""
        },
        @{
            description   = "Deployment location."
            name          = "parLocation"
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

function New-ALZEnvironmentConfig {
    param(
        [Parameter(Mandatory = $false)]
        [string]$destinationDirectory = "./"
    )
    <#
    .SYNOPSIS
    This function uses Slz configuration as a template to create a new configuration file and a directory structure.
    .EXAMPLE
    New-SlzEnvironmentConfig
    .EXAMPLE
    New-SlzEnvironmentConfig -sourceConfigurationFile "orchestration/scripts/parameters/sovereignLandingZone.parameters.json"
    .PARAMETER destinationDirectory
    The directory to create the new configuration and deployment scripts in.  Defaults to the current directory.
    .OUTPUTS
    System.String. The name of the directory created which holds the newly created configuration.
    #>
    $configuration = Initialize-ConfigurationObject

    Request-ConfigurationValue $configuration[0]
    Request-ConfigurationValue $configuration[1]
    Request-ConfigurationValue $configuration[2]

    return $configuration
}