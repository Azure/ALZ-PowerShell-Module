
function Initialize-ConfigurationObject {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("bicep", "terraform")]
        [string] $alzIacProvider = "bicep"
    )
    <#
    .SYNOPSIS
    This function uses a template configuration to prompt for and return a user specified/modified configuration object.
    .EXAMPLE
    Initialize-ConfigurationObject
    .EXAMPLE
    Initialize-ConfigurationObject -alzIacProvider "bicep"
    .OUTPUTS
    System.Object. The resultant configuration values.
    #>

    if ($alzIacProvider -eq "terraform") {
        throw "Terraform is not yet supported."
    }

    return [pscustomobject]@{
        Prefix      = [pscustomobject]@{
            description  = "The prefix that will be added to all resources created by this deployment."
            names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
            value        = "alz"
            defaultValue = "alz"
        }
        Suffix      = [pscustomobject]@{
            Description  = "The suffix that will be added to all resources created by this deployment."
            Names        = @("parTopLevelManagementGroupSuffix")
            Value        = ""
            DefaultValue = ""
        }
        Location    = [pscustomobject]@{
            Description   = "Deployment location."
            Names         = @("parLocation")
            AllowedValues = @(Get-AzLocation | Sort-Object Location | Select-Object -ExpandProperty Location )
            Value         = ""
        }
        Environment = [pscustomobject]@{
            Description  = "The type of environment that will be created . Example: dev, test, qa, staging, prod"
            Names        = @("parEnvironment")
            DefaultValue = 'prod'
            Value        = ""
        }
    }
}

