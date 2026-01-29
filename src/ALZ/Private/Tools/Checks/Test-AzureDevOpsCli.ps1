function Test-AzureDevOpsCli {
    [CmdletBinding()]
    param()

    $results = @()
    $hasFailure = $false

    Write-Verbose "Checking Azure CLI installation for Azure DevOps"
    $azCliPath = Get-Command az -ErrorAction SilentlyContinue

    if ($azCliPath) {
        $results += @{
            message = "Azure CLI is installed."
            result  = "Success"
        }

        # Check if Azure DevOps extension is installed
        Write-Verbose "Checking Azure DevOps extension"
        $extensionList = az extension list -o json 2>$null | ConvertFrom-Json
        $devopsExtension = $extensionList | Where-Object { $_.name -eq "azure-devops" }

        if ($devopsExtension) {
            $results += @{
                message = "Azure DevOps extension is installed."
                result  = "Success"
            }
        } else {
            Write-Verbose "Azure DevOps extension not found, attempting to install..."
            $null = az extension add --name azure-devops 2>&1
            if ($LASTEXITCODE -eq 0) {
                $results += @{
                    message = "Azure DevOps extension was installed automatically."
                    result  = "Success"
                }
            } else {
                $results += @{
                    message = "Azure DevOps extension is not installed. Install using: az extension add --name azure-devops"
                    result  = "Failure"
                }
                $hasFailure = $true
            }
        }
    } else {
        $results += @{
            message = "Azure CLI is not installed. Follow the instructions here: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
            result  = "Failure"
        }
        $hasFailure = $true
    }

    return @{
        Results    = $results
        HasFailure = $hasFailure
    }
}
