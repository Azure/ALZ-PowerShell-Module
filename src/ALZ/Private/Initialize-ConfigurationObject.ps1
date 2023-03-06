
function Initialize-ConfigurationObject {

    return @(
        @{
            description  = "The prefix that will be added to all resources created by this deployment."
            names        = @("parTopLevelManagementGroupPrefix", "parCompanyPrefix")
            value        = "alz"
            defaultValue = "alz"
        },
        @{
            description  = "The suffix that will be added to all resources created by this deployment."
            names        = @("parTopLevelManagementGroupSuffix")
            value        = ""
            defaultValue = ""
        },
        @{
            description   = "Deployment location."
            names          = @("parLocation")
            allowedValues = @(Get-AzLocation | Sort-Object Location | Select-Object -ExpandProperty Location )
            value         = ""
        }
    )
}

