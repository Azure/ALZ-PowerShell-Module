function Request-ALZConfigurationValue {
    <#
    .SYNOPSIS
    Parses configuration files and prompts the user for input values interactively.
    .DESCRIPTION
    This function reads the inputs.yaml file, loads the schema for descriptions and help links,
    and prompts the user for values. It prompts for all inputs in inputs.yaml.
    .PARAMETER ConfigFolderPath
    The path to the folder containing the configuration files.
    .PARAMETER IacType
    The Infrastructure as Code type (terraform or bicep).
    .PARAMETER VersionControl
    The version control system (github, azure-devops, or local).
    .PARAMETER AzureContext
    A hashtable containing Azure context information including ManagementGroups, Subscriptions, and Regions arrays.
    .PARAMETER SensitiveOnly
    When set, only prompts for sensitive inputs that are not already set (via environment variables or non-empty config values).
    .OUTPUTS
    Returns $true if configuration was updated, $false otherwise.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ConfigFolderPath,

        [Parameter(Mandatory = $true)]
        [string] $IacType,

        [Parameter(Mandatory = $true)]
        [string] $VersionControl,

        [Parameter(Mandatory = $false)]
        [hashtable] $AzureContext = @{ ManagementGroups = @(); Subscriptions = @(); Regions = @() },

        [Parameter(Mandatory = $false)]
        [switch] $SensitiveOnly
    )

    # Helper function to get a property from schema info safely
    function Get-SchemaProperty {
        param($SchemaInfo, $PropertyName, $Default = $null)
        if ($null -ne $SchemaInfo -and $SchemaInfo.PSObject.Properties.Name -contains $PropertyName) {
            return $SchemaInfo.$PropertyName
        }
        return $Default
    }

    # Helper function to validate and prompt for a value with GUID format
    function Get-ValidatedGuidInput {
        param($PromptText, $CurrentValue, $Indent = "  ")
        $guidRegex = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        $newValue = Read-Host "$PromptText"
        if ([string]::IsNullOrWhiteSpace($newValue)) {
            return $CurrentValue
        }
        while ($newValue -notmatch $guidRegex) {
            Write-InformationColored "${Indent}Invalid GUID format. Please enter a valid GUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)" -ForegroundColor Red -InformationAction Continue
            $newValue = Read-Host "$PromptText"
            if ([string]::IsNullOrWhiteSpace($newValue)) {
                return $CurrentValue
            }
        }
        return $newValue
    }

    # Helper function to prompt for a single input value
    function Read-InputValue {
        param(
            $Key,
            $CurrentValue,
            $SchemaInfo,
            $Indent = "",
            $DefaultDescription = "No description available",
            $Subscriptions = @(),
            $ManagementGroups = @(),
            $Regions = @()
        )

        $description = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "description" -Default $DefaultDescription
        $helpLink = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "helpLink"
        $isSensitive = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "sensitive" -Default $false
        $allowedValues = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "allowedValues"
        $format = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "format"
        $schemaType = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "type" -Default "string"
        $isRequired = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "required" -Default $false
        $source = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "source"

        # For sensitive inputs, check if value is set via environment variable
        $envVarValue = $null
        if ($isSensitive) {
            $envVarName = "TF_VAR_$Key"
            $envVarValue = [System.Environment]::GetEnvironmentVariable($envVarName)
            if (-not [string]::IsNullOrWhiteSpace($envVarValue)) {
                $CurrentValue = $envVarValue
            }
        }

        # Check if the current value is an array
        $isArray = $schemaType -eq "array" -or $CurrentValue -is [System.Collections.IList]

        # Check if the current value is a placeholder (surrounded by angle brackets)
        $isPlaceholder = $false
        $hasPlaceholderItems = $false
        if ($isArray) {
            # Check if array contains placeholder items
            if ($null -ne $CurrentValue -and $CurrentValue.Count -gt 0) {
                foreach ($item in $CurrentValue) {
                    if ($item -is [string] -and $item -match '^\s*<.*>\s*$') {
                        $hasPlaceholderItems = $true
                        break
                    }
                }
            }
        } elseif ($CurrentValue -is [string] -and $CurrentValue -match '^\s*<.*>\s*$') {
            $isPlaceholder = $true
        }

        # Determine effective default (don't use placeholders as defaults)
        $effectiveDefault = if ($isPlaceholder) { "" } elseif ($isArray -and $hasPlaceholderItems) { @() } else { $CurrentValue }

        # Display prompt information
        Write-InformationColored "`n${Indent}[$Key]" -ForegroundColor Yellow -InformationAction Continue
        Write-InformationColored "${Indent}  $description" -ForegroundColor White -InformationAction Continue
        if ($null -ne $helpLink) {
            Write-InformationColored "${Indent}  Help: $helpLink" -ForegroundColor Gray -InformationAction Continue
        }
        if ($isRequired) {
            Write-InformationColored "${Indent}  Required: Yes" -ForegroundColor Magenta -InformationAction Continue
        }
        if ($null -ne $allowedValues) {
            Write-InformationColored "${Indent}  Allowed values: $($allowedValues -join ', ')" -ForegroundColor Gray -InformationAction Continue
        }
        if ($format -eq "guid") {
            Write-InformationColored "${Indent}  Format: GUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)" -ForegroundColor Gray -InformationAction Continue
        }
        if ($schemaType -eq "number") {
            Write-InformationColored "${Indent}  Format: Integer number" -ForegroundColor Gray -InformationAction Continue
        }
        if ($schemaType -eq "boolean") {
            Write-InformationColored "${Indent}  Format: true or false" -ForegroundColor Gray -InformationAction Continue
        }
        if ($isArray) {
            Write-InformationColored "${Indent}  Format: Comma-separated list of values" -ForegroundColor Gray -InformationAction Continue
        }

        # Helper to mask sensitive values - show first 3 and last 3 chars if long enough
        function Get-MaskedValue {
            param($Value)
            if ([string]::IsNullOrWhiteSpace($Value)) {
                return "(empty)"
            }
            $valueStr = $Value.ToString()
            if ($valueStr.Length -ge 8) {
                # Show first 3 and last 3 characters with asterisks in between
                return $valueStr.Substring(0, 3) + "***" + $valueStr.Substring($valueStr.Length - 3)
            } else {
                # Too short to show partial, just mask completely
                return "********"
            }
        }

        # Show current value (mask if sensitive)
        if ($isArray) {
            $displayCurrentValue = if ($null -eq $CurrentValue -or $CurrentValue.Count -eq 0) {
                "(empty)"
            } elseif ($hasPlaceholderItems) {
                "$($CurrentValue -join ', ') (contains placeholders - requires input)"
            } elseif ($isSensitive) {
                ($CurrentValue | ForEach-Object { Get-MaskedValue -Value $_ }) -join ", "
            } else {
                $CurrentValue -join ", "
            }
        } else {
            $displayCurrentValue = if ($isSensitive -and -not [string]::IsNullOrWhiteSpace($CurrentValue)) {
                Get-MaskedValue -Value $CurrentValue
            } elseif ($isPlaceholder) {
                "$CurrentValue (placeholder - requires input)"
            } elseif ($CurrentValue -is [bool]) {
                # Display booleans in lowercase
                if ($CurrentValue) { "true" } else { "false" }
            } else {
                $CurrentValue
            }
        }
        Write-InformationColored "${Indent}  Current value: $displayCurrentValue" -ForegroundColor Gray -InformationAction Continue

        # Build prompt text
        if ($isArray) {
            # Use effective default (empty if has placeholders)
            $effectiveArrayDefault = if ($hasPlaceholderItems) { @() } else { $CurrentValue }
            $currentAsString = if ($null -eq $effectiveArrayDefault -or $effectiveArrayDefault.Count -eq 0) {
                ""
            } elseif ($isSensitive) {
                ($effectiveArrayDefault | ForEach-Object { Get-MaskedValue -Value $_ }) -join ", "
            } else {
                $effectiveArrayDefault -join ", "
            }
            $promptText = if ([string]::IsNullOrWhiteSpace($currentAsString)) {
                "${Indent}  Enter values (comma-separated)"
            } else {
                "${Indent}  Enter values (comma-separated, default: $currentAsString)"
            }
        } else {
            $displayDefault = if ($isSensitive -and -not [string]::IsNullOrWhiteSpace($effectiveDefault)) {
                Get-MaskedValue -Value $effectiveDefault
            } elseif ($effectiveDefault -is [bool]) {
                # Display booleans in lowercase
                if ($effectiveDefault) { "true" } else { "false" }
            } else {
                $effectiveDefault
            }
            $promptText = if ([string]::IsNullOrWhiteSpace($effectiveDefault) -and $effectiveDefault -isnot [bool]) {
                "${Indent}  Enter value"
            } else {
                "${Indent}  Enter value (default: $displayDefault)"
            }
        }

        # Get new value based on input type
        if ($isSensitive) {
            $secureValue = Read-Host "$promptText" -AsSecureString
            $newValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
            )
            if ([string]::IsNullOrWhiteSpace($newValue)) {
                $newValue = $effectiveDefault
            }
            # Require value if required
            while ($isRequired -and [string]::IsNullOrWhiteSpace($newValue)) {
                Write-InformationColored "${Indent}  This field is required. Please enter a value." -ForegroundColor Red -InformationAction Continue
                $secureValue = Read-Host "$promptText" -AsSecureString
                $newValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
                )
            }
        } elseif ($isArray) {
            $inputValue = Read-Host "$promptText"
            # Use effective default (empty array if has placeholders)
            $effectiveArrayDefault = if ($hasPlaceholderItems) { @() } else { $CurrentValue }
            if ([string]::IsNullOrWhiteSpace($inputValue)) {
                $newValue = $effectiveArrayDefault
            } else {
                # Parse comma-separated values into an array
                $newValue = @($inputValue -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
        } elseif ($source -eq "subscription" -and $Subscriptions.Count -gt 0) {
            # Show subscription selection list
            Write-InformationColored "${Indent}  Available subscriptions:" -ForegroundColor Cyan -InformationAction Continue
            for ($i = 0; $i -lt $Subscriptions.Count; $i++) {
                $sub = $Subscriptions[$i]
                if ($sub.id -eq $effectiveDefault) {
                    Write-InformationColored "${Indent}    [$($i + 1)] $($sub.name) ($($sub.id)) (current)" -ForegroundColor Green -InformationAction Continue
                } else {
                    Write-InformationColored "${Indent}    [$($i + 1)] $($sub.name) ($($sub.id))" -ForegroundColor White -InformationAction Continue
                }
            }
            Write-InformationColored "${Indent}    [0] Enter manually" -ForegroundColor Gray -InformationAction Continue

            $selection = Read-Host "${Indent}  Select subscription (1-$($Subscriptions.Count), 0 for manual entry, or press Enter for default)"
            if ([string]::IsNullOrWhiteSpace($selection)) {
                $newValue = $effectiveDefault
            } elseif ($selection -eq "0") {
                $newValue = Get-ValidatedGuidInput -PromptText "${Indent}  Enter subscription ID" -CurrentValue $effectiveDefault -Indent "${Indent}  "
            } else {
                $selIndex = [int]$selection - 1
                if ($selIndex -ge 0 -and $selIndex -lt $Subscriptions.Count) {
                    $newValue = $Subscriptions[$selIndex].id
                } else {
                    Write-InformationColored "${Indent}  Invalid selection, using default" -ForegroundColor Yellow -InformationAction Continue
                    $newValue = $effectiveDefault
                }
            }
            # Require value if required
            while ($isRequired -and [string]::IsNullOrWhiteSpace($newValue)) {
                Write-InformationColored "${Indent}  This field is required. Please select a subscription." -ForegroundColor Red -InformationAction Continue
                $selection = Read-Host "${Indent}  Select subscription (1-$($Subscriptions.Count), 0 for manual entry)"
                if ($selection -eq "0") {
                    $newValue = Get-ValidatedGuidInput -PromptText "${Indent}  Enter subscription ID" -CurrentValue "" -Indent "${Indent}  "
                } elseif (-not [string]::IsNullOrWhiteSpace($selection)) {
                    $selIndex = [int]$selection - 1
                    if ($selIndex -ge 0 -and $selIndex -lt $Subscriptions.Count) {
                        $newValue = $Subscriptions[$selIndex].id
                    }
                }
            }
        } elseif ($source -eq "managementGroup" -and $ManagementGroups.Count -gt 0) {
            # Show management group selection list
            Write-InformationColored "${Indent}  Available management groups:" -ForegroundColor Cyan -InformationAction Continue
            for ($i = 0; $i -lt $ManagementGroups.Count; $i++) {
                $mg = $ManagementGroups[$i]
                if ($mg.id -eq $effectiveDefault) {
                    Write-InformationColored "${Indent}    [$($i + 1)] $($mg.displayName) ($($mg.id)) (current)" -ForegroundColor Green -InformationAction Continue
                } else {
                    Write-InformationColored "${Indent}    [$($i + 1)] $($mg.displayName) ($($mg.id))" -ForegroundColor White -InformationAction Continue
                }
            }
            Write-InformationColored "${Indent}    [0] Enter manually" -ForegroundColor Gray -InformationAction Continue
            Write-InformationColored "${Indent}    Press Enter to leave empty (uses Tenant Root Group)" -ForegroundColor Gray -InformationAction Continue

            $selection = Read-Host "${Indent}  Select management group (1-$($ManagementGroups.Count), 0 for manual entry, or press Enter for default)"
            if ([string]::IsNullOrWhiteSpace($selection)) {
                $newValue = $effectiveDefault
            } elseif ($selection -eq "0") {
                $newValue = Read-Host "${Indent}  Enter management group ID"
                if ([string]::IsNullOrWhiteSpace($newValue)) {
                    $newValue = $effectiveDefault
                }
            } else {
                $selIndex = [int]$selection - 1
                if ($selIndex -ge 0 -and $selIndex -lt $ManagementGroups.Count) {
                    $newValue = $ManagementGroups[$selIndex].id
                } else {
                    Write-InformationColored "${Indent}  Invalid selection, using default" -ForegroundColor Yellow -InformationAction Continue
                    $newValue = $effectiveDefault
                }
            }
        } elseif ($source -eq "azureRegion" -and $Regions.Count -gt 0) {
            # Show region selection list
            Write-InformationColored "${Indent}  Available regions (AZ = Availability Zone support):" -ForegroundColor Cyan -InformationAction Continue
            for ($i = 0; $i -lt $Regions.Count; $i++) {
                $region = $Regions[$i]
                $azIndicator = if ($region.hasAvailabilityZones) { " [AZ]" } else { "" }
                if ($region.name -eq $effectiveDefault) {
                    Write-InformationColored "${Indent}    [$($i + 1)] $($region.displayName) ($($region.name))$azIndicator (current)" -ForegroundColor Green -InformationAction Continue
                } else {
                    Write-InformationColored "${Indent}    [$($i + 1)] $($region.displayName) ($($region.name))$azIndicator" -ForegroundColor White -InformationAction Continue
                }
            }
            Write-InformationColored "${Indent}    [0] Enter manually" -ForegroundColor Gray -InformationAction Continue

            $selection = Read-Host "${Indent}  Select region (1-$($Regions.Count), 0 for manual entry, or press Enter for default)"
            if ([string]::IsNullOrWhiteSpace($selection)) {
                $newValue = $effectiveDefault
            } elseif ($selection -eq "0") {
                $newValue = Read-Host "${Indent}  Enter region name (e.g., uksouth, eastus)"
                if ([string]::IsNullOrWhiteSpace($newValue)) {
                    $newValue = $effectiveDefault
                }
            } else {
                $selIndex = [int]$selection - 1
                if ($selIndex -ge 0 -and $selIndex -lt $Regions.Count) {
                    $newValue = $Regions[$selIndex].name
                } else {
                    Write-InformationColored "${Indent}  Invalid selection, using default" -ForegroundColor Yellow -InformationAction Continue
                    $newValue = $effectiveDefault
                }
            }
            # Require value if required
            while ($isRequired -and [string]::IsNullOrWhiteSpace($newValue)) {
                Write-InformationColored "${Indent}  This field is required. Please select a region." -ForegroundColor Red -InformationAction Continue
                $selection = Read-Host "${Indent}  Select region (1-$($Regions.Count), 0 for manual entry)"
                if ($selection -eq "0") {
                    $newValue = Read-Host "${Indent}  Enter region name (e.g., uksouth, eastus)"
                } elseif (-not [string]::IsNullOrWhiteSpace($selection)) {
                    $selIndex = [int]$selection - 1
                    if ($selIndex -ge 0 -and $selIndex -lt $Regions.Count) {
                        $newValue = $Regions[$selIndex].name
                    }
                }
            }
        } elseif ($format -eq "guid") {
            $newValue = Get-ValidatedGuidInput -PromptText $promptText -CurrentValue $effectiveDefault -Indent "${Indent}  "
            # Require value if required
            while ($isRequired -and [string]::IsNullOrWhiteSpace($newValue)) {
                Write-InformationColored "${Indent}  This field is required. Please enter a value." -ForegroundColor Red -InformationAction Continue
                $newValue = Get-ValidatedGuidInput -PromptText $promptText -CurrentValue $effectiveDefault -Indent "${Indent}  "
            }
        } elseif ($schemaType -eq "number") {
            $newValue = Read-Host "$promptText"
            if ([string]::IsNullOrWhiteSpace($newValue)) {
                $newValue = $effectiveDefault
            }
            # Validate integer format and require if required
            $intResult = 0
            # Check if effective default is valid, if not clear it
            if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                $valueToCheck = if ($newValue -is [int]) { $newValue.ToString() } else { $newValue }
                while (-not [int]::TryParse($valueToCheck, [ref]$intResult)) {
                    Write-InformationColored "${Indent}  Invalid format. Please enter an integer number." -ForegroundColor Red -InformationAction Continue
                    $newValue = Read-Host "${Indent}  Enter value"
                    if ([string]::IsNullOrWhiteSpace($newValue)) {
                        $newValue = ""
                        break
                    }
                    $valueToCheck = $newValue
                }
            }
            # Require value if required
            while ($isRequired -and [string]::IsNullOrWhiteSpace($newValue)) {
                Write-InformationColored "${Indent}  This field is required. Please enter a value." -ForegroundColor Red -InformationAction Continue
                $newValue = Read-Host "${Indent}  Enter value"
                # Re-validate integer format
                if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                    while (-not [int]::TryParse($newValue, [ref]$intResult)) {
                        Write-InformationColored "${Indent}  Invalid format. Please enter an integer number." -ForegroundColor Red -InformationAction Continue
                        $newValue = Read-Host "${Indent}  Enter value"
                        if ([string]::IsNullOrWhiteSpace($newValue)) {
                            break
                        }
                    }
                }
            }
            # Convert to integer if we have a valid value
            if (-not [string]::IsNullOrWhiteSpace($newValue) -and [int]::TryParse($newValue.ToString(), [ref]$intResult)) {
                $newValue = $intResult
            }
        } elseif ($schemaType -eq "boolean") {
            $newValue = Read-Host "$promptText"
            if ([string]::IsNullOrWhiteSpace($newValue)) {
                $newValue = $effectiveDefault
            }
            # Validate and convert boolean
            if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                $validBooleans = @('true', 'false', 'yes', 'no', '1', '0')
                $valueStr = $newValue.ToString().ToLower()
                while ($validBooleans -notcontains $valueStr) {
                    Write-InformationColored "${Indent}  Invalid format. Please enter true or false." -ForegroundColor Red -InformationAction Continue
                    $newValue = Read-Host "$promptText"
                    if ([string]::IsNullOrWhiteSpace($newValue)) {
                        $newValue = $effectiveDefault
                        break
                    }
                    $valueStr = $newValue.ToString().ToLower()
                }
                # Convert to actual boolean
                if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                    $valueStr = $newValue.ToString().ToLower()
                    $newValue = $valueStr -in @('true', 'yes', '1')
                }
            }
        } else {
            $newValue = Read-Host "$promptText"
            if ([string]::IsNullOrWhiteSpace($newValue)) {
                $newValue = $effectiveDefault
            }
            # Require value if required
            while ($isRequired -and [string]::IsNullOrWhiteSpace($newValue)) {
                Write-InformationColored "${Indent}  This field is required. Please enter a value." -ForegroundColor Red -InformationAction Continue
                $newValue = Read-Host "$promptText"
            }
        }

        # Validate against allowed values if specified
        if ($null -ne $allowedValues -and -not [string]::IsNullOrWhiteSpace($newValue)) {
            while ($allowedValues -notcontains $newValue) {
                Write-InformationColored "${Indent}  Invalid value. Please choose from: $($allowedValues -join ', ')" -ForegroundColor Red -InformationAction Continue
                $newValue = Read-Host "$promptText"
                if ([string]::IsNullOrWhiteSpace($newValue)) {
                    $newValue = $effectiveDefault
                }
            }
        }

        # Return value along with sensitivity info
        return @{
            Value       = $newValue
            IsSensitive = $isSensitive
        }
    }

    if ($PSCmdlet.ShouldProcess("Configuration files", "prompt for input values")) {
        # Load the schema file
        $schemaPath = Join-Path $PSScriptRoot "AcceleratorInputSchema.json"
        if (-not (Test-Path $schemaPath)) {
            Write-Warning "Schema file not found at $schemaPath. Proceeding without descriptions."
            $schema = $null
        } else {
            $schema = Get-Content -Path $schemaPath -Raw | ConvertFrom-Json
        }

        # Define the configuration files to process
        $inputsYamlPath = Join-Path $ConfigFolderPath "inputs.yaml"

        $configUpdated = $false

        # Process inputs.yaml - prompt for ALL inputs
        if (Test-Path $inputsYamlPath) {
            Write-InformationColored "`n=== Bootstrap Configuration (inputs.yaml) ===" -ForegroundColor Cyan -InformationAction Continue
            Write-InformationColored "For more information, see: https://aka.ms/alz/acc/phase0" -ForegroundColor Gray -InformationAction Continue

            # Read the raw content to preserve comments and ordering
            $inputsYamlContent = Get-Content -Path $inputsYamlPath -Raw
            $inputsConfig = $inputsYamlContent | ConvertFrom-Yaml -Ordered
            $inputsUpdated = $false

            # Track changes to apply to the raw content
            $changes = @{}

            # Get the appropriate schema sections based on version control
            $bootstrapSchema = $null
            $vcsSchema = $null
            if ($null -ne $schema) {
                $bootstrapSchema = $schema.inputs.bootstrap.properties
                if ($VersionControl -eq "github") {
                    $vcsSchema = $schema.inputs.github.properties
                } elseif ($VersionControl -eq "azure-devops") {
                    $vcsSchema = $schema.inputs.azure_devops.properties
                } elseif ($VersionControl -eq "local") {
                    $vcsSchema = $schema.inputs.local.properties
                }
            }

            foreach ($key in @($inputsConfig.Keys)) {
                $currentValue = $inputsConfig[$key]

                # Handle nested subscription_ids object (always in schema)
                if ($key -eq "subscription_ids" -and $currentValue -is [System.Collections.IDictionary]) {
                    # Skip subscription_ids in SensitiveOnly mode (subscription IDs are not sensitive)
                    if ($SensitiveOnly.IsPresent) {
                        continue
                    }

                    # Only process if subscription_ids is in the schema
                    if ($null -eq $bootstrapSchema -or -not ($bootstrapSchema.PSObject.Properties.Name -contains "subscription_ids")) {
                        continue
                    }

                    Write-InformationColored "`n[subscription_ids]" -ForegroundColor Yellow -InformationAction Continue
                    Write-InformationColored "  The subscription IDs for the platform landing zone subscriptions" -ForegroundColor White -InformationAction Continue
                    Write-InformationColored "  Help: https://aka.ms/alz/acc/phase0" -ForegroundColor Gray -InformationAction Continue

                    $subscriptionIdsSchema = $bootstrapSchema.subscription_ids.properties

                    foreach ($subKey in @($currentValue.Keys)) {
                        $subCurrentValue = $currentValue[$subKey]
                        $subSchemaInfo = $null

                        if ($null -ne $subscriptionIdsSchema -and $subscriptionIdsSchema.PSObject.Properties.Name -contains $subKey) {
                            $subSchemaInfo = $subscriptionIdsSchema.$subKey
                        } else {
                            # Skip subscription IDs not in schema
                            continue
                        }

                        $result = Read-InputValue -Key $subKey -CurrentValue $subCurrentValue -SchemaInfo $subSchemaInfo -Indent "  " -DefaultDescription "Subscription ID for $subKey" -Subscriptions $AzureContext.Subscriptions -ManagementGroups $AzureContext.ManagementGroups -Regions $AzureContext.Regions
                        $subNewValue = $result.Value
                        $subIsSensitive = $result.IsSensitive

                        if ($subNewValue -ne $subCurrentValue -or $subIsSensitive) {
                            $currentValue[$subKey] = $subNewValue
                            $changes["subscription_ids.$subKey"] = @{
                                OldValue    = $subCurrentValue
                                NewValue    = $subNewValue
                                Key         = $subKey
                                IsNested    = $true
                                IsSensitive = $subIsSensitive
                            }
                            $inputsUpdated = $true
                        }
                    }
                    continue
                }

                # Skip inputs that are not in the schema
                $schemaInfo = $null
                $isInBootstrapSchema = $null -ne $bootstrapSchema -and $bootstrapSchema.PSObject.Properties.Name -contains $key
                $isInVcsSchema = $null -ne $vcsSchema -and $vcsSchema.PSObject.Properties.Name -contains $key

                if (-not $isInBootstrapSchema -and -not $isInVcsSchema) {
                    # This input is not in the schema, skip it
                    continue
                }

                # Look up schema info from bootstrap or VCS-specific schema
                if ($isInBootstrapSchema) {
                    $schemaInfo = $bootstrapSchema.$key
                } elseif ($isInVcsSchema) {
                    $schemaInfo = $vcsSchema.$key
                }

                # Check if this is a sensitive input
                $isSensitiveField = Get-SchemaProperty -SchemaInfo $schemaInfo -PropertyName "sensitive" -Default $false

                # In SensitiveOnly mode, skip non-sensitive inputs
                if ($SensitiveOnly.IsPresent -and -not $isSensitiveField) {
                    continue
                }

                # In SensitiveOnly mode, check if sensitive value is already set
                if ($SensitiveOnly.IsPresent -and $isSensitiveField) {
                    # Check environment variable first
                    $envVarName = "TF_VAR_$key"
                    $envVarValue = [System.Environment]::GetEnvironmentVariable($envVarName)
                    if (-not [string]::IsNullOrWhiteSpace($envVarValue)) {
                        Write-InformationColored "`n[$key] - Already set via environment variable $envVarName" -ForegroundColor Gray -InformationAction Continue
                        continue
                    }

                    # Check if config value is a real value (not empty, not a placeholder)
                    $isPlaceholderValue = $currentValue -is [string] -and $currentValue -match '^\s*<.*>\s*$'
                    $isSetViaEnvVarPlaceholder = $currentValue -is [string] -and $currentValue -like "Set via environment variable*"
                    if (-not [string]::IsNullOrWhiteSpace($currentValue) -and -not $isPlaceholderValue -and -not $isSetViaEnvVarPlaceholder) {
                        Write-InformationColored "`n[$key] - Already set in configuration" -ForegroundColor Gray -InformationAction Continue
                        continue
                    }
                }

                $result = Read-InputValue -Key $key -CurrentValue $currentValue -SchemaInfo $schemaInfo -Subscriptions $AzureContext.Subscriptions -ManagementGroups $AzureContext.ManagementGroups -Regions $AzureContext.Regions
                $newValue = $result.Value
                $isSensitive = $result.IsSensitive

                # Update if changed (handle array comparison) or if sensitive (always track sensitive values)
                $hasChanged = $false
                if ($currentValue -is [System.Collections.IList] -or $newValue -is [System.Collections.IList]) {
                    # Compare arrays
                    $currentArray = @($currentValue)
                    $newArray = @($newValue)
                    if ($currentArray.Count -ne $newArray.Count) {
                        $hasChanged = $true
                    } else {
                        for ($i = 0; $i -lt $currentArray.Count; $i++) {
                            if ($currentArray[$i] -ne $newArray[$i]) {
                                $hasChanged = $true
                                break
                            }
                        }
                    }
                } else {
                    $hasChanged = $newValue -ne $currentValue
                }

                if ($hasChanged -or $isSensitive) {
                    $inputsConfig[$key] = $newValue
                    $changes[$key] = @{
                        OldValue    = $currentValue
                        NewValue    = $newValue
                        Key         = $key
                        IsNested    = $false
                        IsArray     = $newValue -is [System.Collections.IList]
                        IsBoolean   = $newValue -is [bool]
                        IsNumber    = $newValue -is [int] -or $newValue -is [long] -or $newValue -is [double]
                        IsSensitive = $isSensitive
                    }
                    $inputsUpdated = $true
                }
            }

            # Save updated inputs.yaml preserving comments and ordering
            if ($inputsUpdated) {
                $updatedContent = $inputsYamlContent
                $sensitiveEnvVars = @{}

                foreach ($changeKey in $changes.Keys) {
                    $change = $changes[$changeKey]
                    $key = $change.Key
                    $oldValue = $change.OldValue
                    $newValue = $change.NewValue
                    $isArray = if ($change.ContainsKey('IsArray')) { $change.IsArray } else { $false }
                    $isBoolean = if ($change.ContainsKey('IsBoolean')) { $change.IsBoolean } else { $false }
                    $isNumber = if ($change.ContainsKey('IsNumber')) { $change.IsNumber } else { $false }
                    $isSensitive = if ($change.ContainsKey('IsSensitive')) { $change.IsSensitive } else { $false }

                    # Handle sensitive values - set as environment variable instead of in file
                    if ($isSensitive -and -not [string]::IsNullOrWhiteSpace($newValue)) {
                        $envVarName = "TF_VAR_$key"
                        [System.Environment]::SetEnvironmentVariable($envVarName, $newValue)
                        $sensitiveEnvVars[$key] = $envVarName

                        # Update the config file to indicate it's set as an env var
                        $envVarPlaceholder = "Set via environment variable $envVarName"
                        $escapedOldValue = if ([string]::IsNullOrWhiteSpace($oldValue)) { "" } else { [regex]::Escape($oldValue) }
                        if ([string]::IsNullOrWhiteSpace($escapedOldValue)) {
                            $pattern = "(?m)^(\s*${key}:\s*)`"?`"?(\s*)(#.*)?$"
                        } else {
                            $pattern = "(?m)^(\s*${key}:\s*)`"?${escapedOldValue}`"?(\s*)(#.*)?$"
                        }
                        $replacement = "`${1}`"$envVarPlaceholder`"`${2}`${3}"
                        $updatedContent = $updatedContent -replace $pattern, $replacement
                        continue
                    }

                    if ($isArray) {
                        # Handle array values - convert to YAML inline array format
                        $yamlArrayValue = "[" + (($newValue | ForEach-Object { "`"$_`"" }) -join ", ") + "]"

                        # Match the existing array or empty value - use greedy match within brackets
                        # Pattern matches: key: [anything] with optional comment
                        $pattern = "(?m)^(\s*${key}:\s*)\[[^\]]*\](\s*)(#.*)?$"
                        $replacement = "`${1}$yamlArrayValue`${2}`${3}"
                    } elseif ($isBoolean) {
                        # Handle boolean values - no quotes, lowercase true/false
                        $yamlBoolValue = if ($newValue) { "true" } else { "false" }
                        # Match any boolean-like value (true/false/True/False/yes/no) case-insensitively
                        $pattern = "(?mi)^(\s*${key}:\s*)`"?(true|false)`"?(\s*)(#.*)?$"
                        $replacement = "`${1}$yamlBoolValue`${3}`${4}"
                    } elseif ($isNumber) {
                        # Handle numeric values - no quotes
                        $yamlNumValue = $newValue.ToString()
                        $escapedOldValue = [regex]::Escape($oldValue.ToString())
                        $pattern = "(?m)^(\s*${key}:\s*)`"?${escapedOldValue}`"?(\s*)(#.*)?$"
                        $replacement = "`${1}$yamlNumValue`${2}`${3}"
                    } else {
                        # Handle string values
                        # Escape special regex characters in the old value
                        $escapedOldValue = [regex]::Escape($oldValue)

                        # Build regex pattern to match the key-value pair
                        # This handles both quoted and unquoted values
                        if ([string]::IsNullOrWhiteSpace($oldValue)) {
                            # Empty value - match key followed by colon and optional whitespace/quotes
                            $pattern = "(?m)^(\s*${key}:\s*)`"?`"?(\s*)(#.*)?$"
                            $replacement = "`${1}`"$newValue`"`${2}`${3}"
                        } else {
                            # Non-empty value - match the specific value
                            $pattern = "(?m)^(\s*${key}:\s*)`"?${escapedOldValue}`"?(\s*)(#.*)?$"
                            $replacement = "`${1}`"$newValue`"`${2}`${3}"
                        }
                    }

                    $updatedContent = $updatedContent -replace $pattern, $replacement
                }

                $updatedContent | Set-Content -Path $inputsYamlPath -Force -NoNewline
                Write-InformationColored "`nUpdated inputs.yaml" -ForegroundColor Green -InformationAction Continue

                # Display summary of sensitive environment variables
                if ($sensitiveEnvVars.Count -gt 0) {
                    Write-InformationColored "`nSensitive values have been set as environment variables:" -ForegroundColor Yellow -InformationAction Continue
                    foreach ($varKey in $sensitiveEnvVars.Keys) {
                        Write-InformationColored "  $varKey -> $($sensitiveEnvVars[$varKey])" -ForegroundColor Gray -InformationAction Continue
                    }
                    Write-InformationColored "`nThese environment variables are set for the current process only." -ForegroundColor Gray -InformationAction Continue
                    Write-InformationColored "The config file contains placeholders indicating the values are set via environment variables." -ForegroundColor Gray -InformationAction Continue
                }

                $configUpdated = $true
            }
        }

        return $configUpdated
    }
}
