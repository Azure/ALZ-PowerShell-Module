function Grant-SubscriptionCreatorRole {
    <#
.SYNOPSIS
Assigns the 'SubscriptionCreator' role to a specified service principal to allow it to create subscriptions in the specified billing account.

.DESCRIPTION
Assigns the 'SubscriptionCreator' role to a specified service principal to allow it to create subscriptions in the specified billing account.

.EXAMPLE
# Grant the 'SubscriptionCreator' role on the specified Enterprise Agreement billing account - using the 'billingAccountID' and 'enrollmentAccountID' parameters
Grant-SubscriptionCreatorRole -servicePrincipalObjectId "bd42568a-7dd8-489b-bbbb-cb96cfe10fb5" -billingAccountID "1234567" -enrollmentAccountID "987654"

# Grant the 'SubscriptionCreator' role on the specified Enterprise Agreement billing account - using the 'billingResourceID' parameter
Grant-SubscriptionCreatorRole -servicePrincipalObjectId "bd42568a-7dd8-489b-bbbb-cb96cfe10fb5" -billingResourceID "/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/987654"

# Grant the 'SubscriptionCreator' role on the specified Microsoft Customer Agreement billing account - using the 'billingAccountID', 'billingProfileID', and 'invoiceSectionID' parameters
Grant-SubscriptionCreatorRole -servicePrincipalObjectId "bd42568a-7dd8-489b-bbbb-cb96cfe10fb5" -billingAccountID "aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx_xxxx-xx-xx" -billingProfileID "AW4F-xxxx-xxx-xxx" -invoiceSectionID "SH3V-xxxx-xxx-xxx"

# Grant the 'SubscriptionCreator' role on the specified Microsoft Customer Agreement billing account - using the 'billingResourceID' parameter
Grant-SubscriptionCreatorRole -servicePrincipalObjectId "bd42568a-7dd8-489b-bbbb-cb96cfe10fb5" -billingResourceID "/providers/Microsoft.Billing/billingAccounts/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx_xxxx-xx-xx/billingProfiles/AW4F-xxxx-xxx-xxx/invoiceSections/SH3V-xxxx-xxx-xxx"
#>

    [CmdletBinding(DefaultParameterSetName = "Default")]
    param (
        [Parameter(ParameterSetName = "Default", Mandatory = $true, Position = 1, HelpMessage = "(Required) Provide a Service Principal Object ID to grant the 'SubscriptionCreator' role to on the specified billing account. This can be an app registration or a managed identity. Example: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'.")]
        [string]
        $servicePrincipalObjectId,

        [Parameter(ParameterSetName = "Default", Mandatory = $false, Position = 2, HelpMessage = "(Optional) If using an Enterprise Agreement or Microsoft Customer Agreement, provide the billing account ID that the service principal will be granted the 'SubscriptionCreator' role upon. Examples: '1234567' or 'aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx_xxxx-xx-xx'.")]
        [string]
        $billingAccountID = "",

        [Parameter(ParameterSetName = "Default", Mandatory = $false, Position = 3, HelpMessage = "(Optional) If using an Enterprise Agreement, provide the enrollment account ID that the service principal will be granted the 'SubscriptionCreator' role upon. Example: '987654'.")]
        [string]
        $enrollmentAccountID = "",

        [Parameter(ParameterSetName = "Default", Mandatory = $false, Position = 4, HelpMessage = "(Optional) If using a Microsoft Customer Agreement, provide the billing profile ID that the service principal will be granted the 'SubscriptionCreator' role upon. Example: 'AW4F-xxxx-xxx-xxx'.")]
        [string]
        $billingProfileID = "",

        [Parameter(ParameterSetName = "Default", Mandatory = $false, Position = 5, HelpMessage = "(Optional) If using a Microsoft Customer Agreement, provide the invoice section ID that the service principal will be granted the 'SubscriptionCreator' role upon. Example: 'SH3V-xxxx-xxx-xxx'.")]
        [string]
        $invoiceSectionID = "",

        [Parameter(ParameterSetName = "Advanced", Mandatory = $false, Position = 6, HelpMessage = "(Optional) Provide the resource ID for the billing account that the service will be granted the 'SubscriptionCreator' role upon. This differs based on the type of agreement you have. Examples: '/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/987654' or '/providers/Microsoft.Billing/billingAccounts/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx_xxxx-xx-xx/billingProfiles/AW4F-xxxx-xxx-xxx/invoiceSections/SH3V-xxxx-xxx-xxx'.")]
        [string]
        $billingResourceID = "",


        [Parameter(ParameterSetName = "Default", Mandatory = $false, Position = 7, HelpMessage = "(Optional) Provide a the Azure management API url prefix. Default: 'https://management.azure.com'.")]
        [string]
        $managementApiPrefix = "https://management.azure.com"
    )

    # Checks
    Write-Host "Checking inputs..." -ForegroundColor Cyan
    Write-Host ""

    if($null -eq $servicePrincipalObjectId -or $servicePrincipalObjectId -eq "") {
        $errorMessage = "The 'Service Principal Object ID' parameter is required. Please provide a valid value and try again."
        Write-Error $errorMessage
        throw $errorMessage
    }

    $enterpriseAgreementResourceIDFormat = "/providers/Microsoft.Billing/billingAccounts/$billingAccountID/enrollmentAccounts/$enrollmentAccountID"
    $microsoftCustomerAgreementResourceIDFormat = "/providers/Microsoft.Billing/billingAccounts/$billingAccountID/billingProfiles/$billingProfileID/invoiceSections/$invoiceSectionID"

    if($null -ne $billingAccountID -and $billingAccountID -ne "" -and $null -ne $billingResourceID -and $billingResourceID -ne "" -and $null -ne $invoiceSectionID -and $invoiceSectionID -ne "") {
        $billingResourceID = $microsoftCustomerAgreementResourceIDFormat
        Write-Host "Microsoft Customer Agreement (MCA) parameters provided..."
    }

    if($null -ne $billingAccountID -and $billingAccountID -ne "" -and $null -ne $enrollmentAccountID -and $enrollmentAccountID -ne "") {
        $billingResourceID = $enterpriseAgreementResourceIDFormat
        Write-Host "Enterpruse Agreement (EA) parameters provided..."
    }

    if($null -ne $billingResourceID -and $billingResourceID -ne "") {
        Write-Host "Billing Resource ID or required parameters provided..." -ForegroundColor Green
    } else {
        $errorMessage = "No Billing Resource ID or required parameters provided."
        Write-Error $errorMessage
        throw $errorMessage
    }

    Write-Host "Checking the specified billing account resource ID '$($billingResourceID)' exists..." -ForegroundColor Yellow

    # Check $billingResourceID is valid and exists
    $getbillingResourceID = $(az rest --method GET --url "$managementApiPrefix$($billingResourceID)?api-version=2024-04-01") | ConvertFrom-Json

    if ($null -eq $getbillingResourceID) {
        $errorMessage = "The specified billing account resource ID '$($billingResourceID)' does not exist or you do not have access to it. Please check the value and try again. Also ensure you are logged in as the Account Owner for the specified billing account."
        Write-Error $errorMessage
        throw $errorMessage
    } else {
        Write-Host "The specified billing account ID '$($billingResourceID)' exists. Continuing..." -ForegroundColor Green
        Write-Host ""
    }

    # Check $existingSpnMiObjectId is valid and exists
    Write-Host "Checking the specified service principal 'Object ID' '$($servicePrincipalObjectId)' exists..." -ForegroundColor Yellow
    $getexistingSpnMiObjectId = $(az ad sp show --id $servicePrincipalObjectId) | ConvertFrom-Json

    if ($null -eq $getexistingSpnMiObjectId) {
        $errorMessage = "The specified service principal 'Object ID' '$($existingSpnMiObjectId)' does not exist. Please check the value and try again."
        Write-Error $errorMessage
        throw $errorMessage
    } else {
        $finalSpnMiObjectId = $getexistingSpnMiObjectId.id
        $finalSpnMiDisplayName = $getexistingSpnMiObjectId.displayName
        $finalSpnMiType = $getexistingSpnMiObjectId.servicePrincipalType

        Write-Host "The specified service principal 'Object ID' '$($servicePrincipalObjectId)' exists with a Display Name of: '$finalSpnMiDisplayName' with a Type of: '$finalSpnMiType'. Continuing..." -ForegroundColor Green
        Write-Host ""
    }

    # Grant service principal access to the specified EA billing account
    $subscriptionCreatorRoleId = "a0bcee42-bf30-4d1b-926a-48d21664ef71"
    Write-Host "Pre-reqs passed and complete..." -ForegroundColor Cyan
    Write-Host "Granting the 'SubscriptionCreator' role (ID: '$subscriptionCreatorRoleId') on the Billing Account ID of: '$($billingResourceID)' to the AAD Object ID of: '$($finalSpnMiObjectId)' which has the Display Name of: '$($finalSpnMiDisplayName)'..." -ForegroundColor Yellow

    # Get the current AAD Tenant ID
    $tenantId = $(az account show --query tenantId -o tsv)

    # Create GUID for role assignment name
    $roleAssignmentName = New-Guid

    $roleAssignmentHashTable = [ordered]@{
        "properties" = @{
            "principalId"       = "$finalSpnMiObjectId"
            "roleDefinitionId"  = "$billingResourceID/billingRoleDefinitions/$subscriptionCreatorRoleId"
            "principalTenantId" = $tenantId
        }
    }
    $roleAssignmentPayloadJson = $roleAssignmentHashTable | ConvertTo-Json -Depth 100 -Compress
    $roleAssignmentPayloadJson = $roleAssignmentPayloadJson -replace '"', '\"'

    $grantRbac = $(az rest --method PUT --url "$managementApiPrefix$($billingResourceID)/billingRoleAssignments/$($roleAssignmentName)?api-version=2024-04-01" --body $roleAssignmentPayloadJson) | ConvertFrom-Json

    if ($null -eq $grantRbac) {
        $errorMessage = "The 'SubscriptionCreator' role could not be granted to the service principal. Please check the error message above and try again."
        Write-Error $errorMessage
        throw $errorMessage
    } else {
        Write-Host "The 'SubscriptionCreator' role has been granted to the service principal." -ForegroundColor Green
        Write-Host ""
    }

    return
}
