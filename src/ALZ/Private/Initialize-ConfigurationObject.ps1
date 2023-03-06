
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
            name          = @("parLocation")
            allowedValues = @(Get-AzLocation | Select-Object -ExpandProperty Location | Sort-Object Location)
            value         = ""
        }
    )
}

