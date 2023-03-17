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
            Type         = "UserInput"
            Description  = "The prefix that will be added to all resources created by this deployment. (e.g. 'alz')"
            Targets      = @(
                [pscustomobject]@{
                    Name        = "parTopLevelManagementGroupPrefix"
                    Destination = "Parameters"
                },
                [pscustomobject]@{
                    Name        = "parCompanyPrefix"
                    Destination = "Parameters"
                },
                [pscustomobject]@{
                    Name        = "parTargetManagementGroupId"
                    Destination = "Parameters"
                },
                [pscustomobject]@{
                    Name        = "parAssignableScopeManagementGroupId"
                    Destination = "Parameters"
                })
            Value        = ""
            DefaultValue = "alz"
            Valid        = "^[a-zA-Z]{3,5}$"
        }
        Suffix                     = [pscustomobject]@{
            Type         = "UserInput"
            Description  = "The suffix that will be added to all resources created by this deployment. (e.g. 'test')"
            Targets      = @(
                [pscustomobject]@{
                    Name        = "parTopLevelManagementGroupSuffix"
                    Destination = "Parameters"
                })
            Value        = ""
            DefaultValue = ""
            Valid        = "^[a-zA-Z]{0,5}$"
        }
        Location                   = [pscustomobject]@{
            Type          = "UserInput"
            Description   = "Deployment location."
            Targets       = @(
                [pscustomobject]@{
                    Name        = "parLocation"
                    Destination = "Parameters"
                },
                [pscustomobject]@{
                    Name        = "parAutomationAccountLocation"
                    Destination = "Parameters"
                },
                [pscustomobject]@{
                    Name        = "parLogAnalyticsWorkspaceLocation"
                    Destination = "Parameters"
                })
            AllowedValues = @(Get-AzLocation | Sort-Object Location | Select-Object -ExpandProperty Location)
            Value         = ""
        }
        Environment                = [pscustomobject]@{
            Type         = "UserInput"
            Description  = "The type of environment that will be created. (e.g. 'dev', 'test', 'qa', 'staging', 'prod')"
            Targets      = @(
                [pscustomobject]@{
                    Name        = "parEnvironment"
                    Destination = "Parameters"
                })
            Value        = ""
            DefaultValue = 'prod'
            Valid        = "^[a-zA-Z0-9]{2,10}$"
        }
        IdentitySubscriptionId     = [pscustomobject]@{
            Type        = "UserInput"
            Description = "The identifier of the Identity Subscription. (e.g '00000000-0000-0000-0000-000000000000')"
            Valid       = "^( {){0,1}[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(}){0,1}$"
            Targets     = @(
                [pscustomobject]@{
                    Name        = "IdentitySubscriptionId"
                    Destination = "Environment"
                })
            Value       = ""
        }
        ConnectivitySubscriptionId = [pscustomobject]@{
            Type        = "UserInput"
            Description = "The identifier of the Connectivity Subscription. (e.g '00000000-0000-0000-0000-000000000000')"
            Valid       = "^( {){0,1}[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(}){0,1}$"
            Targets     = @(
                [pscustomobject]@{
                    Name        = "ConnectivitySubscriptionId"
                    Destination = "Environment"
                })
            Value       = ""
        }
        ManagementSubscriptionId   = [pscustomobject]@{
            Type        = "UserInput"
            Description = "The identifier of the Management Subscription. (e.g 00000000-0000-0000-0000-000000000000)"
            Valid       = "^( {){0,1}[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(}){0,1}$"
            Targets     = @(
                [pscustomobject]@{
                    Name        = "ManagementSubscriptionId"
                    Destination = "Environment"
                })
            Value       = ""
        }
        BillingAccountId           = [pscustomobject]@{
            Type        = "UserInput"
            Description = "The identifier of the Billing Account. (e.g 00000000-0000-0000-0000-000000000000)"
            Valid       = "^( {){0,1}[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(}){0,1}$"
            Value       = ""
        }
        EnrollmentAccountId        = [pscustomobject]@{
            Type        = "UserInput"
            Description = "The identifier of the Enrollment Account. (e.g 00000000-0000-0000-0000-000000000000)"
            Valid       = "^( {){0,1}[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(}){0,1}$"
            Value       = ""
        }
        LogAnalyticsResourceId     = [pscustomobject]@{
            Type    = "Computed"
            Value   = "/subscriptions/{%ManagementSubscriptionId%}/resourcegroups/alz-logging/providers/microsoft.operationalinsights/workspaces/alz-log-analytics"
            Targets = @(
                [pscustomobject]@{
                    Name        = "parLogAnalyticsWorkspaceResourceId"
                    Destination = "Parameters"
                })
        }
    }
}

