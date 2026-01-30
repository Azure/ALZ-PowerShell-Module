function Test-AzureEnvironmentVariable {
    [CmdletBinding()]
    param()

    $results = @()
    $hasFailure = $false
    $envVarsValid = $false

    Write-Verbose "Checking Azure environment variables"
    $nonAzCliEnvVars = @(
        "ARM_CLIENT_ID",
        "ARM_SUBSCRIPTION_ID",
        "ARM_TENANT_ID"
    )

    $envVarsSet = $true
    $envVarValid = $true
    $envVarUnique = $true
    $envVarAtLeastOneSet = $false
    $envVarsWithValue = @()
    $checkedEnvVars = @()

    foreach($envVar in $nonAzCliEnvVars) {
        $envVarValue = [System.Environment]::GetEnvironmentVariable($envVar)
        if($envVarValue -eq $null -or $envVarValue -eq "" ) {
            $envVarsSet = $false
            continue
        }
        $envVarAtLeastOneSet = $true
        $envVarsWithValue += $envVar
        if($envVarValue -notmatch("^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$")) {
            $envVarValid = $false
            continue
        }
        if($checkedEnvVars -contains $envVarValue) {
            $envVarUnique = $false
            continue
        }
        $checkedEnvVars += $envVarValue
    }

    if($envVarsSet) {
        Write-Verbose "Using Service Principal Authentication"
        if($envVarValid -and $envVarUnique) {
            $results += @{
                message = "Azure environment variables are set and are valid unique GUIDs."
                result  = "Success"
            }
            $envVarsValid = $true
        }

        if(-not $envVarValid) {
            $results += @{
                message = "Azure environment variables are set, but are not all valid GUIDs."
                result  = "Failure"
            }
            $hasFailure = $true
        }

        if (-not $envVarUnique) {
            $envVarValidationOutput = ""
            foreach($envVar in $nonAzCliEnvVars) {
                $envVarValue = [System.Environment]::GetEnvironmentVariable($envVar)
                $envVarValidationOutput += " $envVar ($envVarValue)"
            }
            $results += @{
                message = "Azure environment variables are set, but are not unique GUIDs. There is at least one duplicate:$envVarValidationOutput."
                result  = "Failure"
            }
            $hasFailure = $true
        }
    } else {
        if($envVarAtLeastOneSet) {
            $envVarValidationOutput = ""
            foreach($envVar in $envVarsWithValue) {
                $envVarValue = [System.Environment]::GetEnvironmentVariable($envVar)
                $envVarValidationOutput += " $envVar ($envVarValue)"
            }
            $results += @{
                message = "At least one environment variable is set, but the other expected environment variables are not set. This could cause Terraform to fail in unexpected ways. Set environment variables:$envVarValidationOutput."
                result  = "Warning"
            }
        }
    }

    return @{
        Results      = $results
        HasFailure   = $hasFailure
        EnvVarsValid = $envVarsValid
    }
}
