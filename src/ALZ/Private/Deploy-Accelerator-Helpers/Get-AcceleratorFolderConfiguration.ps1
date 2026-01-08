function Get-AcceleratorFolderConfiguration {
    <#
    .SYNOPSIS
    Detects and validates accelerator folder configuration from existing files.
    .DESCRIPTION
    This function examines an existing accelerator folder to detect the IaC type,
    version control system, and validate the configuration files.
    .PARAMETER FolderPath
    The path to the accelerator folder to analyze.
    .OUTPUTS
    Returns a hashtable with the following keys:
    - IsValid: Boolean indicating if valid configuration was found
    - IacType: Detected IaC type (terraform, bicep, or $null)
    - VersionControl: Detected version control (github, azure-devops, local, or $null)
    - ConfigFolderPath: Path to the config folder
    - InputsYamlPath: Path to inputs.yaml
    - InputsYaml: Parsed inputs.yaml content (if valid)
    - InputsContent: Raw inputs.yaml content (if valid)
    - ErrorMessage: Error message if validation failed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $FolderPath
    )

    $result = @{
        FolderExists     = $false
        IsValid          = $false
        IacType          = $null
        VersionControl   = $null
        ConfigFolderPath = $null
        InputsYamlPath   = $null
        InputsYaml       = $null
        InputsContent    = $null
        ErrorMessage     = $null
    }

    # Check if folder exists
    if (-not (Test-Path -Path $FolderPath)) {
        $result.ErrorMessage = "Folder '$FolderPath' does not exist."
        return $result
    }

    $result.FolderExists = $true

    $configFolderPath = Join-Path $FolderPath "config"
    $inputsYamlPath = Join-Path $configFolderPath "inputs.yaml"

    $result.ConfigFolderPath = $configFolderPath
    $result.InputsYamlPath = $inputsYamlPath

    # Check if config folder exists
    if (-not (Test-Path -Path $configFolderPath)) {
        $result.ErrorMessage = "Config folder not found at '$configFolderPath'"
        return $result
    }

    # Check if inputs.yaml exists
    if (-not (Test-Path -Path $inputsYamlPath)) {
        $result.ErrorMessage = "Required configuration file not found: inputs.yaml"
        return $result
    }

    # Try to read and validate inputs.yaml
    try {
        $inputsContent = Get-Content -Path $inputsYamlPath -Raw
        $inputsYaml = $inputsContent | ConvertFrom-Yaml

        $result.InputsContent = $inputsContent
        $result.InputsYaml = $inputsYaml
        $result.IsValid = $true
    } catch {
        $result.ErrorMessage = "inputs.yaml is not valid YAML: $($_.Exception.Message)"
        return $result
    }

    # Detect IaC type from existing files
    $tfvarsPath = Join-Path $configFolderPath "platform-landing-zone.tfvars"
    $bicepYamlPath = Join-Path $configFolderPath "platform-landing-zone.yaml"

    if (Test-Path -Path $tfvarsPath) {
        $result.IacType = "terraform"
    } elseif (Test-Path -Path $bicepYamlPath) {
        $result.IacType = "bicep"
    }

    # Detect version control from bootstrap_module_name in inputs.yaml
    if ($inputsYaml.bootstrap_module_name) {
        $bootstrapModuleName = $inputsYaml.bootstrap_module_name
        switch ($bootstrapModuleName) {
            "alz_github" { $result.VersionControl = "github" }
            "alz_azuredevops" { $result.VersionControl = "azure-devops" }
            "alz_local" { $result.VersionControl = "local" }
        }
    }

    return $result
}
