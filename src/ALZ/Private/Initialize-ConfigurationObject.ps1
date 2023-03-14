
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
        Prefix                     = [pscustomobject]@{
            Type         = "Configuration"
            Description  = "The prefix that will be added to all resources created by this deployment. (e.g. 'alz')"
            Names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix", "parTargetManagementGroupId", "parAssignableScopeManagementGroupId")
            Value        = "alz"
            DefaultValue = "alz"
            Valid        = "^[a-zA-Z]{3,5}$"
        }
        Suffix                     = [pscustomobject]@{
            Type         = "Configuration"
            Description  = "The suffix that will be added to all resources created by this deployment. (e.g. 'test')"
            Names        = @("parTopLevelManagementGroupSuffix")
            Value        = ""
            DefaultValue = ""
            Valid        = "^[a-zA-Z]{0,5}$"
        }
        Location                   = [pscustomobject]@{
            Type          = "Configuration"
            Description   = "Deployment location."
            Names         = @("parLocation", "parAutomationAccountLocation", "parLogAnalyticsWorkspaceLocation")
            AllowedValues = @(Get-AzLocation | Sort-Object Location | Select-Object -ExpandProperty Location)
            Value         = ""
        }
        Environment                = [pscustomobject]@{
            Type         = "Configuration"
            Description  = "The type of environment that will be created. (e.g. 'dev', 'test', 'qa', 'staging', 'prod')"
            Names        = @("parEnvironment")
            DefaultValue = 'prod'
            Value        = ""
            Valid        = "^[a-zA-Z0-9]{2,10}$"
        }
        IdentitySubscriptionId     = [pscustomobject]@{
            ForEnvironment = $true
            Description    = "The identifier of the Identity subscription. (e.g '00000000-0000-0000-0000-000000000000')"
            Valid          = "^( {){0,1}[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(}){0,1}$"
            Value          = ""
        }
        ConnectivitySubscriptionId = [pscustomobject]@{
            ForEnvironment = $true
            Description    = "The identifier of the Connectivity subscription. (e.g '00000000-0000-0000-0000-000000000000')"
            Valid          = "^( {){0,1}[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(}){0,1}$"
            Value          = ""
        }
        ManagementSubscriptionId   = [pscustomobject]@{
            ForEnvironment = $true
            Description    = "The identifier of the Management subscription. (e.g 00000000-0000-0000-0000-000000000000)"
            Valid          = "^( {){0,1}[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(}){0,1}$"
            Names          = @("parLogAnalyticsWorkspaceResourceId")
            Replace        = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
            Value          = ""
        }
    }
}

