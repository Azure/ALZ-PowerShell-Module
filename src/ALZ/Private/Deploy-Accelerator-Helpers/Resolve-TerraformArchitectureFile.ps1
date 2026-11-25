function Resolve-TerraformArchitectureFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $starterModulePath,

        [Parameter(Mandatory = $false)]
        [string[]] $starterAdditionalFiles = @(),

        [Parameter(Mandatory = $true)]
        [string] $defaultArchitectureFilePath,

        [Parameter(Mandatory = $false)]
        [string] $architectureName = "",

        [Parameter(Mandatory = $false)]
        [string] $existingRootManagementGroupId = ""
    )

    $result = [PSCustomObject]@{
        ArchitectureFilePath = $null
        DefaultFileToRemove  = $null
    }

    $pathComparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
    $defaultArchitectureFilePath = $defaultArchitectureFilePath.Replace('\', '/')
    $libraryFolderName = $defaultArchitectureFilePath.Split('/')[0]
    $defaultFileFullPath = Join-Path -Path $starterModulePath -ChildPath $defaultArchitectureFilePath
    $defaultFileExists = Test-Path -LiteralPath $defaultFileFullPath -PathType Leaf

    function Get-ArchitectureDefinition {
        param([string] $path)
        try {
            $content = Get-Content -LiteralPath $path -Raw
            $definition = if ($path.EndsWith('.json')) { $content | ConvertFrom-Json } else { $content | ConvertFrom-Yaml }
        } catch {
            Write-Verbose "Could not parse architecture definition file ${path}: $_"
            return $null
        }
        if ($null -eq $definition -or $definition.name -isnot [string] -or [string]::IsNullOrWhiteSpace($definition.name)) {
            return $null
        }
        $rootManagementGroupId = @($definition.management_groups | Where-Object { $null -ne $_ -and $null -eq $_.parent_id } | ForEach-Object { $_.id })
        return [PSCustomObject]@{
            Name                  = $definition.name
            RootManagementGroupId = if ($rootManagementGroupId.Count -eq 1) { $rootManagementGroupId[0] } else { $null }
        }
    }

    function Complete-WithoutChange {
        if (-not $defaultFileExists) {
            Write-ToConsoleLog "The bootstrap will read '$defaultArchitectureFilePath', but it is missing from the starter module at $starterModulePath. If an earlier run removed it, run again with -replaceFiles or set 'terraform_architecture_file_path' in your inputs." -IsWarning
        }
        return $result
    }

    $userArchitectureFiles = @()
    foreach ($additionalFile in $starterAdditionalFiles) {
        if (-not (Test-Path -LiteralPath $additionalFile -PathType Container)) {
            continue
        }
        $folderName = ([System.IO.DirectoryInfo]::new($additionalFile)).Name
        if (-not [string]::Equals($folderName, $libraryFolderName, $pathComparison)) {
            continue
        }
        $folderPath = (Resolve-Path -LiteralPath $additionalFile).Path
        $files = Get-ChildItem -LiteralPath $folderPath -File -Recurse -Force | Where-Object { $_.Name -cmatch '\.alz_architecture_definition\.(json|yaml|yml)$' }
        foreach ($file in $files) {
            $relativePath = [System.IO.Path]::GetRelativePath($folderPath, $file.FullName).Replace('\', '/')
            $userArchitectureFiles += [PSCustomObject]@{
                SourcePath      = $file.FullName
                DestinationPath = "$folderName/$relativePath"
            }
        }
    }

    if ($userArchitectureFiles.Count -eq 0) {
        return Complete-WithoutChange
    }

    if (@($userArchitectureFiles | Where-Object { [string]::Equals($_.DestinationPath, $defaultArchitectureFilePath, $pathComparison) }).Count -gt 0) {
        return $result
    }

    $needsYaml = @($userArchitectureFiles | Where-Object { -not $_.SourcePath.EndsWith('.json') }).Count -gt 0 -or ($defaultFileExists -and -not $defaultFileFullPath.EndsWith('.json'))
    if ($needsYaml -and $null -eq (Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
        Write-ToConsoleLog "Found architecture definition files ($($userArchitectureFiles.DestinationPath -join ', ')) but the powershell-yaml module is not available to read them, so the bootstrap will use '$defaultArchitectureFilePath'. Install powershell-yaml or set 'terraform_architecture_file_path' in your inputs." -IsWarning
        return Complete-WithoutChange
    }

    $defaultDefinition = if ($defaultFileExists) { Get-ArchitectureDefinition -path $defaultFileFullPath } else { $null }

    $starterArchitectureNames = @(Get-ChildItem -LiteralPath $starterModulePath -Filter '*.tf' -File -ErrorAction SilentlyContinue | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw })
    $fixedNames = @($starterArchitectureNames | ForEach-Object { [regex]::Matches($_, '(?m)^\s*architecture_name\s*=\s*"([^"$]+)"') } | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    $optionalDefaultNames = @($starterArchitectureNames | ForEach-Object { [regex]::Matches($_, 'architecture_name\s*=\s*optional\(\s*string\s*,\s*"([^"$]+)"\s*\)') } | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)

    $targetArchitectureName = $null
    if ($fixedNames.Count -eq 1) {
        $targetArchitectureName = $fixedNames[0]
    } elseif (-not [string]::IsNullOrWhiteSpace($architectureName)) {
        $targetArchitectureName = $architectureName
    } elseif ($optionalDefaultNames.Count -eq 1) {
        $targetArchitectureName = $optionalDefaultNames[0]
    } elseif ($null -ne $defaultDefinition) {
        $targetArchitectureName = $defaultDefinition.Name
    }

    $validFiles = @()
    foreach ($userArchitectureFile in $userArchitectureFiles) {
        $definition = Get-ArchitectureDefinition -path $userArchitectureFile.SourcePath
        if ($null -eq $definition) {
            Write-ToConsoleLog "Skipping architecture definition file '$($userArchitectureFile.DestinationPath)': it could not be read or has no name." -IsWarning
            continue
        }
        $validFiles += [PSCustomObject]@{
            DestinationPath       = $userArchitectureFile.DestinationPath
            Name                  = $definition.Name
            RootManagementGroupId = $definition.RootManagementGroupId
        }
    }

    $candidates = @($validFiles | Where-Object { $null -eq $targetArchitectureName -or $_.Name -ceq $targetArchitectureName })

    if ($candidates.Count -eq 0) {
        Write-ToConsoleLog "Found architecture definition files ($($userArchitectureFiles.DestinationPath -join ', ')) but none has the architecture name '$targetArchitectureName', so the bootstrap will use '$defaultArchitectureFilePath'. Set 'terraform_architecture_file_path' in your inputs to choose a file." -IsWarning
        return Complete-WithoutChange
    }

    if ($candidates.Count -gt 1) {
        if ($null -eq $targetArchitectureName) {
            Write-ToConsoleLog "Found more than one architecture definition file ($($candidates.DestinationPath -join ', ')) and could not tell which one the starter module uses, so the bootstrap will use '$defaultArchitectureFilePath'. Set 'terraform_architecture_file_path' in your inputs to choose a file." -IsWarning
            return Complete-WithoutChange
        }
        $message = "Found more than one architecture definition file for architecture '$targetArchitectureName': $($candidates.DestinationPath -join ', '). Remove the duplicates or set 'terraform_architecture_file_path' in your inputs to choose a file."
        Write-ToConsoleLog $message -IsError
        throw $message
    }

    $selected = $candidates[0]

    if (-not [string]::IsNullOrWhiteSpace($existingRootManagementGroupId) -and $selected.RootManagementGroupId -cne $existingRootManagementGroupId) {
        Write-ToConsoleLog "Your bootstrap manages the intermediate root management group '$existingRootManagementGroupId'. Using '$($selected.DestinationPath)' would change it to '$($selected.RootManagementGroupId)', so the bootstrap will keep using '$defaultArchitectureFilePath'. Set 'terraform_architecture_file_path' in your inputs to switch." -IsWarning
        return Complete-WithoutChange
    }

    Write-Verbose "Using architecture definition file '$($selected.DestinationPath)' for the bootstrap."
    $result.ArchitectureFilePath = $selected.DestinationPath

    if ($null -ne $defaultDefinition -and $defaultDefinition.Name -ceq $selected.Name) {
        $result.DefaultFileToRemove = $defaultFileFullPath
    }

    return $result
}
