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
        [string] $architectureName = ""
    )

    $result = [PSCustomObject]@{
        ArchitectureFilePath = $null
        DefaultFileToRemove  = $null
    }

    $architectureFilePattern = '\.alz_architecture_definition\.(json|ya?ml)$'

    function Get-ArchitectureName {
        param([string] $path)
        $content = Get-Content -Path $path -Raw
        if ($path -match '\.json$') {
            return ($content | ConvertFrom-Json).name
        }
        return ($content | ConvertFrom-Yaml).name
    }

    $userArchitectureFiles = @()
    foreach ($additionalFile in $starterAdditionalFiles) {
        if (Test-Path $additionalFile -PathType Container) {
            $folder = Get-Item -Path $additionalFile
            $files = Get-ChildItem -Path $folder.FullName -File -Recurse -Force | Where-Object { $_.Name -match $architectureFilePattern }
            foreach ($file in $files) {
                $relativePath = [System.IO.Path]::GetRelativePath($folder.FullName, $file.FullName).Replace('\', '/')
                $userArchitectureFiles += [PSCustomObject]@{
                    SourcePath      = $file.FullName
                    DestinationPath = "$($folder.Name)/$relativePath"
                }
            }
        } elseif ((Test-Path $additionalFile -PathType Leaf) -and ([System.IO.Path]::GetFileName($additionalFile) -match $architectureFilePattern)) {
            $userArchitectureFiles += [PSCustomObject]@{
                SourcePath      = (Get-Item -Path $additionalFile).FullName
                DestinationPath = [System.IO.Path]::GetFileName($additionalFile)
            }
        }
    }

    if ($userArchitectureFiles.Count -eq 0) {
        return $result
    }

    $defaultFileFullPath = Join-Path -Path $starterModulePath -ChildPath $defaultArchitectureFilePath
    $defaultArchitectureName = $null
    if (Test-Path $defaultFileFullPath -PathType Leaf) {
        $defaultArchitectureName = Get-ArchitectureName -path $defaultFileFullPath
    }

    $targetArchitectureName = if ([string]::IsNullOrWhiteSpace($architectureName)) { $defaultArchitectureName } else { $architectureName }

    $candidates = @($userArchitectureFiles | Where-Object {
            $null -eq $targetArchitectureName -or (Get-ArchitectureName -path $_.SourcePath) -eq $targetArchitectureName
        })

    if ($candidates.Count -eq 0) {
        Write-ToConsoleLog "Found architecture definition files ($($userArchitectureFiles.DestinationPath -join ', ')) but none has the architecture name '$targetArchitectureName', so the bootstrap will use '$defaultArchitectureFilePath'. Set 'terraform_architecture_file_path' in your inputs to choose a file." -IsWarning
        return $result
    }

    if ($candidates.Count -gt 1) {
        $message = "Found more than one architecture definition file for architecture '$targetArchitectureName': $($candidates.DestinationPath -join ', '). Remove the duplicates or set 'terraform_architecture_file_path' in your inputs to choose a file."
        Write-ToConsoleLog $message -IsError
        throw $message
    }

    $selectedPath = $candidates[0].DestinationPath
    if ($selectedPath -eq $defaultArchitectureFilePath.Replace('\', '/')) {
        return $result
    }

    Write-Verbose "Using architecture definition file '$selectedPath' for the bootstrap."
    $result.ArchitectureFilePath = $selectedPath

    if ($null -ne $defaultArchitectureName -and $defaultArchitectureName -eq $targetArchitectureName) {
        $result.DefaultFileToRemove = $defaultFileFullPath
    }

    return $result
}
