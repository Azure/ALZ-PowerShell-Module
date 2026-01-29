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
            $AzureContext
        )

        # Use pre-fetched Azure context data from parent scope
        $description = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "description" -Default $DefaultDescription
        $helpLink = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "helpLink"
        $isSensitive = Get-SchemaProperty -SchemaInfo $SchemaInfo -PropertyName "sensitive" -Default $false
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

        # Build base parameters for Read-MenuSelection
        $menuParams = @{
            Title             = $Key
            HelpText          = @($description, $helpLink)
            Options           = @()
            DefaultValue      = $effectiveDefault
            AllowManualEntry  = $true
            ManualEntryPrompt = "Enter value (press enter to accept default)"
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
        } elseif ($source -eq "managementGroup") {
            $menuParams.OptionsTitle = "Available management groups:"
            $menuParams.Options = $AzureContext.ManagementGroups
            $menuParams.ManualEntryPrompt = "Enter management group ID"
            $menuParams.RequiredMessage = "This field is required. Please select a management group."
            $menuParams.EmptyMessage = "No management groups found in Azure context."
        } elseif ($source -eq "azureRegion") {
            $menuParams.OptionsTitle = "Available regions (AZ = Availability Zone support):"
            $menuParams.Options = $AzureContext.Regions
            $menuParams.ManualEntryPrompt = "Enter region name (e.g., uksouth, eastus)"
            $menuParams.RequiredMessage = "This field is required. Please select a region."
            $menuParams.EmptyMessage = "No regions found in Azure context."
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
            Write-ToConsoleLog "=== Bootstrap Configuration (inputs.yaml) ==="
            Write-ToConsoleLog "For more information, see: https://aka.ms/alz/acc/phase0"

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

                        $result = Read-InputValue -Key $subKey -CurrentValue $subCurrentValue -SchemaInfo $subSchemaInfo -DefaultDescription "Subscription ID for $subKey" -AzureContext $AzureContext
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
                        Write-ToConsoleLog "[$key] - Already set via environment variable $envVarName"
                        continue
                    }

                    # Check if config value is a real value (not empty, not a placeholder)
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

                        # Check if old value is already in array format or a different format (string/placeholder)
                        $oldValueIsArray = $oldValue -is [System.Collections.IList]
                        if ($oldValueIsArray) {
                            # Match the existing array - greedy match within brackets
                            $pattern = "(?m)^(\s*${key}:\s*)\[[^\]]*\](\s*)(#.*)?$"
                        } else {
                            # Old value was a string/placeholder, match quoted or unquoted value
                            $escapedOldValue = if ([string]::IsNullOrWhiteSpace($oldValue)) { "" } else { [regex]::Escape($oldValue.ToString()) }
                            if ([string]::IsNullOrWhiteSpace($escapedOldValue)) {
                                $pattern = "(?m)^(\s*${key}:\s*)`"?`"?(\s*)(#.*)?$"
                            } else {
                                $pattern = "(?m)^(\s*${key}:\s*)`"?${escapedOldValue}`"?(\s*)(#.*)?$"
                            }
                        }
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
