function Invoke-EABillingSPNPermissionsSetup {
  <#
.SYNOPSIS
Creates a new SPN, or uses an existing SPN/MI, and assigns it the 'SubscriptionCreator' role to it to allow it to create subscriptions in the specified EA billing enrollment account.

.DESCRIPTION
Creates a new SPN, or uses an existing SPN/MI, and assigns it the 'SubscriptionCreator' role to it to allow it to create subscriptions in the specified EA billing enrollment account.

.EXAMPLE
# Create a new SPN and grant it the 'SubscriptionCreator' role on the specified EA billing account - using the 'eaEnrollmentNumber' and 'eaEnrollmentAccountNumber' parameters
/Invoke-EABillingSPNPermissionsSetup.ps1 -eaEnrollmentNumber "123456" -eaEnrollmentAccountNumber "987654"

# Create a new SPN and grant it the 'SubscriptionCreator' role on the specified EA billing account - using the 'eaBillingAccountResourceId' parameter
./Invoke-EABillingSPNPermissionsSetup.ps1 -eaBillingAccountResourceId '/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/987654'

# Create a new SPN, with a custom name, and grant it the 'SubscriptionCreator' role on the specified EA billing account - using the 'eaEnrollmentNumber' and 'eaEnrollmentAccountNumber' parameters
./Invoke-EABillingSPNPermissionsSetup.ps1 -eaEnrollmentNumber "123456" -eaEnrollmentAccountNumber "987654" -newSpnDisplayName 'spn-lz-sub-vending-custom-name'

# Create a new SPN, with a custom name, and grant it the 'SubscriptionCreator' role on the specified EA billing account - using the 'eaBillingAccountResourceId' parameter
./Invoke-EABillingSPNPermissionsSetup.ps1 -eaBillingAccountResourceId '/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/987654' -newSpnDisplayName 'spn-lz-sub-vending-custom-name'

# Use an existing SPN/MI and grant it the 'SubscriptionCreator' role on the specified EA billing account - using the 'eaEnrollmentNumber' and 'eaEnrollmentAccountNumber' parameters
./Invoke-EABillingSPNPermissionsSetup.ps1 -eaEnrollmentNumber "123456" -eaEnrollmentAccountNumber "987654" -existingSpnMiObjectId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

# Use an existing SPN/MI and grant it the 'SubscriptionCreator' role on the specified EA billing account - using the 'eaBillingAccountResourceId' parameter
./Invoke-EABillingSPNPermissionsSetup.ps1 -eaBillingAccountResourceId '/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/987654' -existingSpnMiObjectId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
.NOTES
# Release notes 22/12/2022 - V1.0.0:
- Initial release.

# Release notes 23/12/2022 - V1.1.0:
- Added simplified inputs for the 'eaEnrollmentNumber' and 'eaEnrollmentAccountNumber' parameters to form the 'eaBillingAccountResourceId' parameter value, instead of having to provide the full resource ID in the 'eaBillingAccountResourceId' parameter.
#>

  # Check for pre-reqs
  #Requires -PSEdition Core
  #Requires -Modules @{ ModuleName="Az.Accounts"; ModuleVersion="2.10.4" }
  #Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="6.5.0" }

  [CmdletBinding(DefaultParameterSetName = "Default")]
  param (
    [Parameter(ParameterSetName = "Default", Mandatory = $false, Position = 1, HelpMessage = "Provide the EA enrollment number that the SPN will be granted the 'SubscriptionCreator' role upon. Example: '1234567'. This parameter is only used if the 'eaBillingAccountResourceId' parameter is not provided. It's value is used to create the 'eaBillingAccountResourceId' parameter value, that looks like this: '/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/987654' (this parameter value is the middle numerical value).")]
    [string]
    $eaEnrollmentNumber,

    [Parameter(ParameterSetName = "Default", Mandatory = $false, Position = 2, HelpMessage = "Provide the EA enrollment Account Number/ID that the SPN will be granted the 'SubscriptionCreator' role upon. Example: '987654'. This parameter is only used if the 'eaBillingAccountResourceId' parameter is not provided. It's value is used to create the 'eaBillingAccountResourceId' parameter value, that looks like this: '/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/987654' (this parameter value is the middle numerical value).")]
    [string]
    $eaEnrollmentAccountNumber,

    [Parameter(ParameterSetName = "Advanced", Mandatory = $false, Position = 4, HelpMessage = "Provide the EA enrollment/billing account ID that the SPN will be granted the 'SubscriptionCreator' role upon. Example: '/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/123456'")]
    [string]
    $eaBillingAccountResourceId,

    [Parameter(ParameterSetName = "Default", Mandatory = $false, Position = 3, HelpMessage = "(Optional) Provide an existing Service Principal Name (SPN) (aka Enterprise Application) 'Object ID' to grant the 'SubscriptionCreator' role to on the specified billing account instead of creating a new one. If left blank a new SPN will be created. This can also be the object ID of a Managed Identity's SPN.")]
    [string]
    $existingSpnMiObjectId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",

    [Parameter(ParameterSetName = "Default", Mandatory = $false, Position = 5, HelpMessage = "(Optional) Provide a Display Name for the new Service Principal (SPN) (aka Enterprise Application) to be created. If left blank the default value of 'spn-lz-sub-vending' will be used.")]
    [string]
    $newSpnDisplayName = "spn-lz-sub-vending"
  )

  # Checks
  Write-Host "Checking inputs..." -ForegroundColor Cyan
  Write-Host ""

  # Check $eaBillingAccountResourceId is valid and populate from $eaEnrollmentNumber and $eaEnrollmentAccountNumber if not provided
  if ($eaBillingAccountResourceId -eq $null -or $eaBillingAccountResourceId -eq "") {
    Write-Host "eaBillingAccountResourceId paramter value not set, forming parameter value from eaEnrollmentNumber and eaEnrollmentAccountNumber parameters..." -ForegroundColor Magenta
    if ($eaEnrollmentNumber -eq $null -or $eaEnrollmentAccountNumber -eq $null -or $eaEnrollmentNumber -eq '' -or $eaEnrollmentAccountNumber -eq '') {
      throw "No values provdided for the 'eaEnrollmentNumber' and 'eaEnrollmentAccountNumber' parameters. These parameters are required if the 'eaBillingAccountResourceId' parameter is not provided. Please provide values for these parameters and try again."
    }
    $eaBillingAccountResourceId = "/providers/Microsoft.Billing/billingAccounts/$eaEnrollmentNumber/enrollmentAccounts/$eaEnrollmentAccountNumber"
    Write-Host "eaBillingAccountResourceId parameter value set to '$($eaBillingAccountResourceId)'" -ForegroundColor Green
    Write-Host ""
  }

  # Check $eaBillingAccountResourceId is valid and exists
  Write-Host "EA billing account parameters provided..." -ForegroundColor Cyan
  Write-Host "Checking the specified EA billing account ID '$($eaBillingAccountResourceId)' exists..." -ForegroundColor Yellow

  if ($null -ne $eaBillingAccountResourceId -and $eaBillingAccountResourceId -ne "") {
    $geteaBillingAccountResourceId = Invoke-AzRestMethod -Method GET -Path "$($eaBillingAccountResourceId)?api-version=2019-10-01-preview" -ErrorAction SilentlyContinue

    if ($geteaBillingAccountResourceId.StatusCode -ne 200) {
      Write-Error "HTTP Status Code: $($geteaBillingAccountResourceId.StatusCode)"
      Write-Error "HTTP Repsone Content: $($geteaBillingAccountResourceId.Content)"
      throw "The specified EA billing account ID '$($eaBillingAccountResourceId)' does not exist. Please check the value and try again. Also ensure you are logged in as the EA Account Owner for the specified EA billing account."
    } else {
      Write-Host "The specified EA billing account ID '$($eaBillingAccountResourceId)' exists. Continuing..." -ForegroundColor Green
      Write-Host ""
    }
  }

  # Check $existingSpnMiObjectId is valid and exists
  if ($existingSpnMiObjectId -ne $null -and $existingSpnMiObjectId -ne "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx") {
    Write-Host "Existing SPN/MI provided..." -ForegroundColor Cyan
    Write-Host "Checking the specified SPN/MI 'Object ID' '$($existingSpnMiObjectId)' exists..." -ForegroundColor Yellow
    $getexistingSpnMiObjectId = Get-AzADServicePrincipal -ObjectId $existingSpnMiObjectId -ErrorAction SilentlyContinue

    if ($null -eq $getexistingSpnMiObjectId) {
      throw "The specified SPN/MI 'Object ID' '$($existingSpnMiObjectId)' does not exist. Please check the value and try again."
    } else {
      Write-Host "The specified SPN/MI 'Object ID' '$($existingSpnMiObjectId)' exists with a Display Name of: '$($getexistingSpnMiObjectId.DisplayName)' with a Type of: '$($getexistingSpnMiObjectId.ServicePrincipalType)'. Continuing..." -ForegroundColor Green
      Write-Host ""
      $finalSpnMiObjectId = $getexistingSpnMiObjectId.Id
      $finalSpnMiAppId = $getexistingSpnMiObjectId.AppId
      $finalSpnMiDisplayName = $getexistingSpnMiObjectId.DisplayName
      $finalSpnMiType = $getexistingSpnMiObjectId.ServicePrincipalType
    }
  } else {
    # Create a new SPN (aka Enterprise Application) as no existing SPN/MI was provided via the $existingSpnMiObjectId parameter
    Write-Host "No Existing SPN/MI provided. Proceeding to create a new SPN (aka Enterprise Application)..." -ForegroundColor Cyan
    Write-Host "Creating a new SPN (aka Enterprise Application) with a Display Name of '$($newSpnDisplayName)'..." -ForegroundColor Yellow

    $newSpn = New-AzADServicePrincipal -DisplayName $newSpnDisplayName -Description "Service Principal Name (SPN) for the Landing Zone Subscription Vending. See https://aka.ms/lz-vending/bicep or https://aka.ms/lz-vending/tf for more information." -ErrorAction Stop
    Write-Host "New SPN (aka Enterprise Application) created with a Display Name of '$($newSpn.DisplayName)' and an Object ID of '$($newSpn.Id)'." -ForegroundColor Green
    Write-Host ""

    $finalSpnMiObjectId = $newSpn.Id
    $finalSpnMiDisplayName = $newSpn.DisplayName
    $finalSpnMiType = $newSpn.ServicePrincipalType
    $finalSpnMiAppId = $newSpn.AppId
  }

  ## convert this to a retry loop
  # Start-Sleep -Seconds 15

  # Grant SPN/MI access to the specified EA billing account
  Write-Host "Pre-reqs passed and complete..." -ForegroundColor Cyan
  Write-Host "Granting the 'SubscriptionCreator' role (ID: 'a0bcee42-bf30-4d1b-926a-48d21664ef71') on the EA Billing Account ID of: '$($eaBillingAccountResourceId)' to the AAD Object ID of: '$($finalSpnMiObjectId)' which has the Display Name of: '$($finalSpnMiDisplayName)'..." -ForegroundColor Yellow

  # Get the current AAD Tenant ID
  $currentTenant = Get-AzTenant -ErrorAction Stop

  # Create GUID for role assignment name
  $roleAssignmentName = New-Guid

  $roleAssignmentHashTable = [ordered]@{
    "properties" = @{
      "principalId"       = "$finalSpnMiObjectId"
      "roleDefinitionId"  = "$eaBillingAccountResourceId/billingRoleDefinitions/a0bcee42-bf30-4d1b-926a-48d21664ef71"
      "principalTenantId" = "$($currentTenant.TenantId)"
    }
  }
  $roleAssignmentPayloadJson = $roleAssignmentHashTable | ConvertTo-Json -Depth 100

  $grantRbac = Invoke-AzRestMethod -Method PUT -Path "$($eaBillingAccountResourceId)/billingRoleAssignments/$($roleAssignmentName)?api-version=2019-10-01-preview" -Payload $roleAssignmentPayloadJson -ErrorAction SilentlyContinue

  # Create variables for retry loop
  $retryCount = 0
  $retryLimit = 10
  $retryDelay = 5


  if ($grantRbac.StatusCode -eq 400 -and $grantRbac.Content.Contains("are not valid")) {
    while ($retryCount -le $retryLimit) {
      Write-Host "The 'SubscriptionCreator' role has not been granted to the SPN/MI. Retrying in $retryDelay seconds to allow platform replication to occur..." -ForegroundColor Magenta

      Start-Sleep -Seconds $retryDelay
      $retryCount++

      $grantRbac = Invoke-AzRestMethod -Method PUT -Path "$($eaBillingAccountResourceId)/billingRoleAssignments/$($roleAssignmentName)?api-version=2019-10-01-preview" -Payload $roleAssignmentPayloadJson -ErrorAction SilentlyContinue

      if ($grantRbac.StatusCode -eq 200) {
        break
      }
    }
  }
  if ($grantRbac.StatusCode -ne 200) {
    Write-Error "HTTP Status Code: $($grantRbac.StatusCode)"
    Write-Error "HTTP Repsone Content: $($grantRbac.Content)"
    throw "An error occurred while attempting to grant the 'SubscriptionCreator' role to the SPN/MI. Please check the error message above and try again."
  } else {
    Write-Host "The 'SubscriptionCreator' role has been granted to the SPN/MI." -ForegroundColor Green
    Write-Host ""
    Write-Host "The SPN/MI 'Object ID' is: '$($finalSpnMiObjectId)'" -ForegroundColor Green
    Write-Host "The SPN/MI 'App ID' is: '$($finalSpnMiAppId)'" -ForegroundColor Green
    Write-Host "The SPN/MI 'Display Name' is: '$($finalSpnMiDisplayName)'" -ForegroundColor Green
    Write-Host "The SPN/MI 'Type' is: '$($finalSpnMiType)'" -ForegroundColor Green
  }

  return
}