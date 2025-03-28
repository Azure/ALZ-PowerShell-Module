function Get-ALZConfig {
    param(
        [Parameter(Mandatory = $false)]
        [string] $configFilePath = "",
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $inputConfig = $null,
        [Parameter(Mandatory = $false)]
        [string] $hclParserToolPath = ""
    )

    if (!(Test-Path $configFilePath)) {
        Write-Error "The config file does not exist at $configFilePath"
        throw "The config file does not exist at $configFilePath"
    }

    if ($null -eq $inputConfig) {
        $inputConfig = [PSCustomObject]@{}
    }

    # Import the config and transform it to a PowerShell object
    $extension = (Get-Item -Path $configFilePath).Extension.ToLower()
    $config = $null
    if ($extension -eq ".yml" -or $extension -eq ".yaml") {
        if (!(Get-Module -ListAvailable -Name powershell-Yaml)) {
            Write-Host "Installing YAML module"
            Install-Module powershell-Yaml -Force
        }
        try {
            $config = [PSCustomObject](Get-Content -Path $configFilePath | ConvertFrom-Yaml -Ordered)
        } catch {
            $errorMessage = "Failed to parse YAML inputs. Please check the YAML file for errors and try again. $_"
            Write-Error $errorMessage
            throw $errorMessage
        }

    } elseif ($extension -eq ".json") {
        try {
            $config = [PSCustomObject](Get-Content -Path $configFilePath | ConvertFrom-Json)
        } catch {
            $errorMessage = "Failed to parse JSON inputs. Please check the JSON file for errors and try again. $_"
            Write-Error $errorMessage
            throw $errorMessage
        }
    } elseif ($extension -eq ".tfvars") {
        try {
            $config = [PSCustomObject](& $hclParserToolPath $configFilePath | ConvertFrom-Json)
        } catch {
            $errorMessage = "Failed to parse HCL inputs. Please check the HCL file for errors and try again. $_"
            Write-Error $errorMessage
            throw $errorMessage
        }
    } else {
        throw "The config file must be a json, yaml/yml or tfvars file"
    }

    Write-Verbose "Config file loaded from $configFilePath with $($config.PSObject.Properties.Name.Count) properties."

    foreach ($property in $config.PSObject.Properties) {
        $inputConfig | Add-Member -NotePropertyName $property.Name -NotePropertyValue @{
            Value  = $property.Value
            Source = $extension
        }
    }

    return $inputConfig
}
