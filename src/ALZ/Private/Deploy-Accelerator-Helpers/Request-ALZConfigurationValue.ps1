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
    .PARAMETER AzureContextOutputDirectory
    The output directory to pass to Get-AzureContext for caching Azure context data.
    .PARAMETER AzureContextClearCache
    When set, clears the cached Azure context data before fetching.
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
        [string] $AzureContextOutputDirectory = "",

        [Parameter(Mandatory = $false)]
        [switch] $AzureContextClearCache,

        [Parameter(Mandatory = $false)]
        [int] $ScenarioNumber = 0,

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

    # Helper function to prompt for a single input value
    function Read-InputValue {
        param(
            $Key,
            $CurrentValue,
            $SchemaInfo,
            $Indent = "",
            $DefaultDescription = "No description available",
            $AzureContext,
            [switch]$SkipSubscriptionDefault
        )

        # Use pre-fetched Azure context data from parent scope
        $description = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "description" -Default $DefaultDescription
        $helpLink = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "helpLink"
        $isSensitive = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "sensitive" -Default $false
        $schemaType = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "type" -Default "string"
        $isRequired = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "required" -Default $false
        $source = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "source"

        if ($Key -in @("management", "connectivity", "identity", "security")) {
            $description = $description -replace "\b$([regex]::Escape($Key))(?=\s+subscription\b)", "$([char]27)[33m`$&$([char]27)[0m"
        }

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
        $hasEffectiveDefault = $null -ne $effectiveDefault -and -not [string]::IsNullOrWhiteSpace($effectiveDefault)

        # Build base parameters for Read-MenuSelection
        $menuParams = @{
            Title             = $Key
            HelpText          = @($description, $helpLink)
            Options           = @()
            DefaultValue      = $effectiveDefault
            AllowManualEntry  = $true
            ManualEntryPrompt = if ($hasEffectiveDefault) { "Enter value (press enter to accept default)" } else { "Enter value" }
            Type              = $schemaType
            IsRequired        = $isRequired
            RequiredMessage   = "This field is required. Please enter a value."
            IsSensitive       = $isSensitive
        }

        # Customize parameters based on input type
        if ($isArray) {
            $menuParams.HelpText = @($description, $helpLink, "Format: Comma-separated list of values")
            $menuParams.ManualEntryPrompt = "Enter values (comma-separated)"
            $menuParams.RequiredMessage = "This field is required. Please enter values."
        } elseif ($source -eq "subscription") {
            $menuParams.OptionsTitle = "Available subscriptions:"
            $menuParams.Options = $AzureContext.Subscriptions
            $menuParams.ManualEntryPrompt = "Enter subscription ID"
            $menuParams.RequiredMessage = "This field is required. Please select a subscription."
            $menuParams.EmptyMessage = "No subscriptions found in Azure context."
            $menuParams.DefaultOptionMarker = ""
            if ($Key -eq "bootstrap_subscription_id" -and -not [string]::IsNullOrWhiteSpace($AzureContext.CurrentSubscriptionId)) {
                $menuParams.DefaultValue = $AzureContext.CurrentSubscriptionId
                $menuParams.DefaultOptionMarker = "current"
            } elseif ($Key -in @("management", "connectivity", "identity", "security") -and [string]::IsNullOrWhiteSpace($effectiveDefault) -and -not $SkipSubscriptionDefault) {
                $subscriptionsWithNames = @($AzureContext.Subscriptions | ForEach-Object {
                        $subscriptionName = if ($_.PSObject.Properties.Name -contains "name") {
                            $_.name
                        } else {
                            $_.label -replace '\s+\([^)]+\)$', ''
                        }
                        [PSCustomObject]@{
                            Name  = $subscriptionName
                            Value = $_.value
                        }
                    })
                # Prefer a friendly name match for workload-style keys like "management" or
                # "connectivity" so the user is not forced to choose manually when the answer is obvious.
                $exactMatches = @($subscriptionsWithNames | Where-Object { $_.Name -ieq $Key })
                $wordMatchPattern = "(?<!\w)$([regex]::Escape($Key))(?!\w)"
                $wordMatches = @($subscriptionsWithNames | Where-Object { $_.Name -match $wordMatchPattern })
                if ($exactMatches.Count -eq 1) {
                    $menuParams.DefaultValue = $exactMatches[0].Value
                    $menuParams.DefaultOptionMarker = "matched"
                } elseif ($wordMatches.Count -eq 1) {
                    $menuParams.DefaultValue = $wordMatches[0].Value
                    $menuParams.DefaultOptionMarker = "matched"
                }
                # Optional values can legitimately be skipped, so a no-match result falls back to
                # manual entry instead of forcing a selection before the user decides to leave it blank.
                if (-not $isRequired -and [string]::IsNullOrWhiteSpace($menuParams.DefaultValue)) {
                    $menuParams.ManualEntryLabel = "Enter manually or don't supply"
                    $menuParams.DefaultToManualEntry = $true
                    $menuParams.DefaultValue = ""
                }
            } elseif (-not $isRequired -and [string]::IsNullOrWhiteSpace($effectiveDefault)) {
                $menuParams.ManualEntryLabel = "Enter manually or don't supply"
                $menuParams.DefaultToManualEntry = $true
                $menuParams.DefaultValue = ""
            }
        } elseif ($source -eq "managementGroup") {
            $menuParams.OptionsTitle = "Available management groups:"
            $menuParams.Options = $AzureContext.ManagementGroups
            $menuParams.ManualEntryPrompt = "Enter management group ID"
            $menuParams.RequiredMessage = "This field is required. Please select a management group."
            $menuParams.EmptyMessage = "No management groups found in Azure context."
            if ($Key -eq "root_parent_management_group_id" -and [string]::IsNullOrWhiteSpace($effectiveDefault) -and -not [string]::IsNullOrWhiteSpace($AzureContext.CurrentTenantId)) {
                $menuParams.DefaultValue = $AzureContext.CurrentTenantId
            }
        } elseif ($source -eq "azureRegion") {
            $menuParams.OptionsTitle = "Available regions (AZ = Availability Zone support):"
            $menuParams.Options = $AzureContext.Regions
            $menuParams.ManualEntryPrompt = "Enter region name (e.g., uksouth, eastus)"
            $menuParams.RequiredMessage = "This field is required. Please select a region."
            $menuParams.EmptyMessage = "No regions found in Azure context."
            $azureDefaultRegion = [System.Environment]::GetEnvironmentVariable("AZURE_DEFAULTS_REGION")
            if ([string]::IsNullOrWhiteSpace($effectiveDefault) -and -not [string]::IsNullOrWhiteSpace($azureDefaultRegion)) {
                $regionOption = $AzureContext.Regions | Where-Object { $_.value -ieq $azureDefaultRegion } | Select-Object -First 1
                if ($null -ne $regionOption) {
                    $menuParams.DefaultValue = $regionOption.value
                }
            }
        } elseif ($schemaType -eq "boolean") {
            $menuParams.ManualEntryPrompt = "Enter value (true/false) (press enter to accept default)"
            $menuParams.DefaultValue = $effectiveDefault.ToString().ToLower()
        }

        $newValue = Read-MenuSelection @menuParams

        # Return value along with sensitivity info
        return @{
            Value       = $newValue
            IsSensitive = $isSensitive
        }
    }

    if ($PSCmdlet.ShouldProcess("Configuration files", "prompt for input values")) {
        $AzureContext = $null

        # Fetch Azure context once upfront if not in SensitiveOnly mode
        if (-not $SensitiveOnly.IsPresent) {
            if (-not [string]::IsNullOrWhiteSpace($AzureContextOutputDirectory)) {
                $AzureContext = Get-AzureContext -OutputDirectory $AzureContextOutputDirectory -ClearCache:$AzureContextClearCache.IsPresent
            } else {
                $AzureContext = Get-AzureContext -ClearCache:$AzureContextClearCache.IsPresent
            }
        }

        Write-Verbose (ConvertTo-Json $AzureContext)

        # Load the schema file
        $schemaPath = Join-Path $PSScriptRoot "AcceleratorInputSchema.json"
        if (-not (Test-Path $schemaPath)) {
            Write-ToConsoleLog "Schema file not found at $schemaPath. Proceeding without descriptions." -IsWarning
            $schema = $null
        } else {
            $schema = Get-Content -Path $schemaPath -Raw -Force | ConvertFrom-Json
        }

        # Define the configuration files to process
        $inputsYamlPath = Join-Path $ConfigFolderPath "inputs.yaml"

        $configUpdated = $false

        # Process inputs.yaml - prompt for ALL inputs
        if (Test-Path $inputsYamlPath) {
            Write-ToConsoleLog "=== Bootstrap Configuration (inputs.yaml) ==="
            Write-ToConsoleLog "For more information, see: https://aka.ms/alz/acc/phase0"

            # Read the raw content to preserve comments and ordering
            $inputsYamlContent = Get-Content -Path $inputsYamlPath -Raw -Force
            $inputsConfig = $inputsYamlContent | ConvertFrom-Yaml -Ordered
            $inputsUpdated = $false
            $sensitiveEnvVars = @{}

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

            # Helper: look up schema info for a key from bootstrap or VCS schema
            function Get-InputSchemaInfo {
                param($Key, $BootstrapSchema, $VcsSchema)
                if ($null -ne $BootstrapSchema -and $BootstrapSchema.PSObject.Properties.Name -contains $Key) {
                    return $BootstrapSchema.$Key
                }
                if ($null -ne $VcsSchema -and $VcsSchema.PSObject.Properties.Name -contains $Key) {
                    return $VcsSchema.$Key
                }
                return $null
            }

            # Helper: format a value for inline YAML output (strongly typed)
            function Format-YamlInlineValue {
                param($Value)
                if ($null -eq $Value) { return "" }
                if ($Value -is [bool]) { if ($Value) { return "true" } else { return "false" } }
                if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) { return $Value.ToString() }
                if ($Value -is [System.Collections.IList]) {
                    if ($Value.Count -eq 0) { return "[]" }
                    $items = ($Value | ForEach-Object { "`"$_`"" }) -join ", "
                    return "[$items]"
                }
                if ($Value -is [System.Collections.IDictionary]) { return "" }
                return "`"$Value`""
            }

            foreach ($key in @($inputsConfig.Keys)) {
                $currentValue = $inputsConfig[$key]

                # Handle nested dictionary objects generically (e.g. subscription_ids)
                if ($currentValue -is [System.Collections.IDictionary]) {
                    if ($SensitiveOnly.IsPresent) {
                        continue
                    }

                    $parentSchemaInfo = Get-InputSchemaInfo -Key $key -BootstrapSchema $bootstrapSchema -VcsSchema $vcsSchema
                    if ($null -eq $parentSchemaInfo) {
                        continue
                    }

                    $nestedSchema = Get-SchemaProperty -SchemaInfo $parentSchemaInfo -PropertyName "properties"
                    if ($null -eq $nestedSchema) {
                        continue
                    }

                    # Iterate using schema property order to ensure consistent display ordering
                    foreach ($subKey in @($nestedSchema.PSObject.Properties.Name)) {
                        if (-not $currentValue.Contains($subKey)) {
                            continue
                        }
                        $subCurrentValue = $currentValue[$subKey]
                        $subSchemaInfo = $nestedSchema.$subKey

                        $skipSubscriptionDefault = (
                            $key -eq "subscription_ids" `
                                -and $ScenarioNumber -eq 5 `
                                -and $subKey -ne "management"
                        )

                        # For management-only scenario, only management is required
                        if ($skipSubscriptionDefault) {
                            $subSchemaInfo = $subSchemaInfo.PSObject.Copy()
                            $subSchemaInfo | Add-Member -MemberType NoteProperty -Name "required" -Value $false -Force
                        }

                        $result = Read-InputValue -Key $subKey -CurrentValue $subCurrentValue -SchemaInfo $subSchemaInfo -DefaultDescription "$key - $subKey" -AzureContext $AzureContext -SkipSubscriptionDefault:$skipSubscriptionDefault
                        $subNewValue = $result.Value

                        if ($skipSubscriptionDefault -and [string]::IsNullOrWhiteSpace($subNewValue)) {
                            $currentValue.Remove($subKey)
                            $inputsUpdated = $true
                            continue
                        }

                        if ($subNewValue -ne $subCurrentValue) {
                            $currentValue[$subKey] = [string]$subNewValue
                            $inputsUpdated = $true
                        }
                    }
                    continue
                }

                # Look up schema info
                $schemaInfo = Get-InputSchemaInfo -Key $key -BootstrapSchema $bootstrapSchema -VcsSchema $vcsSchema
                if ($null -eq $schemaInfo) {
                    continue
                }

                # Check if this is a sensitive input
                $isSensitiveField = Get-SchemaProperty -SchemaInfo $schemaInfo -PropertyName "sensitive" -Default $false
                $schemaType = Get-SchemaProperty -SchemaInfo $schemaInfo -PropertyName "type" -Default "string"

                # In SensitiveOnly mode, skip non-sensitive inputs
                if ($SensitiveOnly.IsPresent -and -not $isSensitiveField) {
                    continue
                }

                # In SensitiveOnly mode, check if sensitive value is already set
                if ($SensitiveOnly.IsPresent -and $isSensitiveField) {
                    $envVarName = "TF_VAR_$key"
                    $envVarValue = [System.Environment]::GetEnvironmentVariable($envVarName)
                    if (-not [string]::IsNullOrWhiteSpace($envVarValue)) {
                        Write-ToConsoleLog "[$key] - Already set via environment variable $envVarName"
                        continue
                    }

                    $isPlaceholderValue = $currentValue -is [string] -and $currentValue -match '^\s*<.*>\s*$'
                    $isSetViaEnvVarPlaceholder = $currentValue -is [string] -and $currentValue -like "Set via environment variable*"
                    if (-not [string]::IsNullOrWhiteSpace($currentValue) -and -not $isPlaceholderValue -and -not $isSetViaEnvVarPlaceholder) {
                        Write-ToConsoleLog "[$key] - Already set in configuration"
                        continue
                    }
                }

                $result = Read-InputValue -Key $key -CurrentValue $currentValue -SchemaInfo $schemaInfo -AzureContext $AzureContext
                $newValue = $result.Value
                $isSensitive = $result.IsSensitive

                # Handle sensitive values - store in env var, set placeholder in hashtable
                if ($isSensitive -and -not [string]::IsNullOrWhiteSpace($newValue)) {
                    $envVarName = "TF_VAR_$key"
                    [System.Environment]::SetEnvironmentVariable($envVarName, $newValue)
                    $sensitiveEnvVars[$key] = $envVarName
                    $inputsConfig[$key] = [string]"Set via environment variable $envVarName"
                    $inputsUpdated = $true
                    continue
                }

                # Determine if value changed (handle array comparison)
                $hasChanged = $false
                if ($currentValue -is [System.Collections.IList] -or $newValue -is [System.Collections.IList]) {
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

                # Always store the value with the correct type for YAML serialization
                switch ($schemaType) {
                    "boolean" {
                        $typedValue = if ($newValue -is [bool]) { $newValue } else { $newValue.ToString().ToLower() -in @('true', 'yes', '1', 'y', 't') }
                        $inputsConfig[$key] = [bool]$typedValue
                    }
                    "number" {
                        $inputsConfig[$key] = [int]$newValue
                    }
                    "array" {
                        $inputsConfig[$key] = [System.Collections.Generic.List[object]]@($newValue)
                    }
                    default {
                        $inputsConfig[$key] = [string]$newValue
                    }
                }
                if ($hasChanged) {
                    $inputsUpdated = $true
                }
            }

            # Save updated inputs.yaml preserving comments and ordering
            if ($inputsUpdated) {
                # Serialize the updated ordered hashtable to YAML
                $serializedYaml = ($inputsConfig | ConvertTo-Yaml).TrimEnd()
                $serializedLines = $serializedYaml -split "`n"

                # Build a lookup from serialized YAML: key (with indentation) -> serialized line
                # Multi-line arrays are converted to inline format
                $serializedLookup = [ordered]@{}
                $currentLookupKey = $null
                $currentLookupKeyName = $null
                $currentLookupIndent = ""
                $pendingArrayItems = @()

                foreach ($sLine in $serializedLines) {
                    if ($sLine -match '^(\s*)([\w_][\w_\-]*):(.*)$') {
                        # Flush any pending array items from the previous key
                        if ($currentLookupKey -and $pendingArrayItems.Count -gt 0) {
                            $inlineArray = "[" + (($pendingArrayItems | ForEach-Object { "`"$_`"" }) -join ", ") + "]"
                            $serializedLookup[$currentLookupKey] = "$currentLookupIndent${currentLookupKeyName}: $inlineArray"
                            $pendingArrayItems = @()
                        }

                        $indent = $Matches[1]
                        $keyName = $Matches[2]
                        $lookupKey = "${indent}${keyName}"
                        $currentLookupKey = $lookupKey
                        $currentLookupKeyName = $keyName
                        $currentLookupIndent = $indent
                        $serializedLookup[$lookupKey] = $sLine
                    } elseif ($sLine -match '^\s*- (.+)$') {
                        # Array continuation line - collect for inline conversion
                        $pendingArrayItems += $Matches[1]
                    }
                }

                # Flush trailing array items
                if ($currentLookupKey -and $pendingArrayItems.Count -gt 0) {
                    $inlineArray = "[" + (($pendingArrayItems | ForEach-Object { "`"$_`"" }) -join ", ") + "]"
                    $serializedLookup[$currentLookupKey] = "$currentLookupIndent${currentLookupKeyName}: $inlineArray"
                }

                # Walk original file lines, merge comments with serialized values
                $originalLines = $inputsYamlContent -split "`n"
                $resultLines = @()
                $pendingSubKeys = @()
                $currentParentKey = $null

                foreach ($originalLine in $originalLines) {
                    $trimmedLine = $originalLine.TrimStart()

                    # Flush pending sub-keys before any non-indented-data line
                    if ($pendingSubKeys.Count -gt 0 -and -not ($originalLine -match '^\s+([\w_][\w_\-]*):')) {
                        $parentSchemaInfo = Get-InputSchemaInfo -Key $currentParentKey -BootstrapSchema $bootstrapSchema -VcsSchema $vcsSchema
                        $schemaOrder = @(($parentSchemaInfo.properties.PSObject.Properties.Name))
                        foreach ($orderedKey in $schemaOrder) {
                            $match = $pendingSubKeys | Where-Object { $_.KeyName -eq $orderedKey } | Select-Object -First 1
                            if ($match) { $resultLines += $match.Line }
                        }
                        $pendingSubKeys = @()
                        $currentParentKey = $null
                    }

                    # Preserve blank lines, comment-only lines, and YAML document markers
                    if ([string]::IsNullOrWhiteSpace($originalLine) -or $trimmedLine.StartsWith('#') -or $trimmedLine -eq '---') {
                        $resultLines += $originalLine
                        continue
                    }

                    # Data line - extract key and look up the serialized value
                    if ($originalLine -match '^(\s*)([\w_][\w_\-]*):') {
                        $indent = $Matches[1]
                        $keyName = $Matches[2]
                        $lookupKey = "${indent}${keyName}"

                        # Track parent key for nested values
                        if ($indent -eq "") {
                            $currentParentKey = if ($inputsConfig.Contains($keyName) -and $inputsConfig[$keyName] -is [System.Collections.IDictionary]) { $keyName } else { $null }
                        }

                        # Buffer nested keys for schema-order output
                        if ($indent.Length -gt 0 -and $null -ne $currentParentKey) {
                            $hashtableValue = $null
                            foreach ($pKey in $inputsConfig.Keys) {
                                if ($inputsConfig[$pKey] -is [System.Collections.IDictionary] -and $inputsConfig[$pKey].Contains($keyName)) {
                                    $hashtableValue = $inputsConfig[$pKey][$keyName]
                                    break
                                }
                            }

                            $formattedValue = Format-YamlInlineValue -Value $hashtableValue
                            $inlineComment = $null
                            if ($originalLine -match '\S\s{2,}(#.*)$') { $inlineComment = $Matches[1] }
                            $newLine = "${indent}${keyName}: $formattedValue"
                            if ($inlineComment) { $newLine = "$newLine  $inlineComment" }
                            $pendingSubKeys += @{ KeyName = $keyName; Line = $newLine }
                            continue
                        }

                        # Extract inline comment from the original line
                        $inlineComment = $null
                        if ($originalLine -match '\S\s{2,}(#.*)$') {
                            $inlineComment = $Matches[1]
                        }

                        if ($serializedLookup.Contains($lookupKey)) {
                            $newLine = $serializedLookup[$lookupKey]

                            # Format the value using our inline formatter for consistent output
                            $hashtableValue = $null
                            if ($indent -eq "" -and $inputsConfig.Contains($keyName)) {
                                $hashtableValue = $inputsConfig[$keyName]
                            }

                            # Use the formatted value for the line
                            if ($null -ne $hashtableValue -and -not ($hashtableValue -is [System.Collections.IDictionary])) {
                                $formattedValue = Format-YamlInlineValue -Value $hashtableValue
                                $newLine = "${indent}${keyName}: $formattedValue"
                            }

                            if ($inlineComment) {
                                $newLine = "$newLine  $inlineComment"
                            }
                            $resultLines += $newLine
                        } else {
                            # Key not found in serialized output, keep original line
                            $resultLines += $originalLine
                        }
                    } else {
                        # Non-key data line (shouldn't normally happen), keep as-is
                        $resultLines += $originalLine
                    }
                }

                # Flush any trailing pending sub-keys
                if ($currentParentKey -and $pendingSubKeys.Count -gt 0) {
                    $parentSchemaInfo = Get-InputSchemaInfo -Key $currentParentKey -BootstrapSchema $bootstrapSchema -VcsSchema $vcsSchema
                    $schemaOrder = @(($parentSchemaInfo.properties.PSObject.Properties.Name))
                    foreach ($orderedKey in $schemaOrder) {
                        $match = $pendingSubKeys | Where-Object { $_.KeyName -eq $orderedKey } | Select-Object -First 1
                        if ($match) { $resultLines += $match.Line }
                    }
                }

                ($resultLines -join "`n") | Set-Content -Path $inputsYamlPath -Force -NoNewline
                Write-ToConsoleLog "Updated inputs.yaml" -IsSuccess

                # Display summary of sensitive environment variables
                if ($sensitiveEnvVars.Count -gt 0) {
                    Write-ToConsoleLog "Sensitive values have been set as environment variables:" -IsWarning
                    foreach ($varKey in $sensitiveEnvVars.Keys) {
                        Write-ToConsoleLog "$varKey -> $($sensitiveEnvVars[$varKey])" -IsSelection -IndentLevel 1
                    }
                    Write-ToConsoleLog "These environment variables are set for the current process only."
                    Write-ToConsoleLog "The config file contains placeholders indicating the values are set via environment variables."
                }

                $configUpdated = $true
            }
        }

        return $configUpdated
    }
}
