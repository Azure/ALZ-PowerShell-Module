targetScope = 'tenant'

metadata name = 'basic managment groups and resource definition'
metadata description = 'This template deploys default management groups for the tenant and assign the basic role definition to the management group.'

@sys.description('Prefix for the management group hierarchy. This management group will be created as part of the deployment.')
@minLength(2)
@maxLength(10)
param parTopLevelManagementGroupPrefix string = 'alz'

@sys.description('Optional suffix for the management group hierarchy. This suffix will be appended to management group names/IDs. Include a preceding dash if required. Example: -suffix')
@maxLength(10)
param parTopLevelManagementGroupSuffix string = ''

@sys.description('Display name for top level management group. This name will be applied to the management group prefix defined in parTopLevelManagementGroupPrefix parameter.')
@minLength(2)
param parTopLevelManagementGroupDisplayName string = 'Azure Landing Zones'

@sys.description('Optional parent for Management Group hierarchy, used as intermediate root Management Group parent, if specified. If empty, default, will deploy beneath Tenant Root Management Group.')
param parTopLevelManagementGroupParentId string = ''

@sys.description('Deploys Corp & Online Management Groups beneath Landing Zones Management Group if set to true.')
param parLandingZoneMgAlzDefaultsEnable bool = true

@sys.description('Deploys Confidential Corp & Confidential Online Management Groups beneath Landing Zones Management Group if set to true.')
param parLandingZoneMgConfidentialEnable bool = false

@sys.description('Dictionary Object to allow additional or different child Management Groups of Landing Zones Management Group to be deployed.')
param parLandingZoneMgChildren object = {}

@sys.description('Set Parameter to true to Opt-out of deployment telemetry.')
param parTelemetryOptOut bool = false

@sys.description('The management group scope to which the role can be assigned. This management group ID will be used for the assignableScopes property in the role definition.')
param parAssignableScopeManagementGroupId string = 'alz'



module managmentGroups '../alz-bicep-internal/infra-as-code/bicep/modules/managementGroups/managementGroups.bicep' = {
  scope: tenant()
  name: 'mgRoot'
  params: {
    parTopLevelManagementGroupPrefix: parTopLevelManagementGroupPrefix
    parTopLevelManagementGroupSuffix: parTopLevelManagementGroupSuffix
    parTopLevelManagementGroupDisplayName: parTopLevelManagementGroupDisplayName
    parTopLevelManagementGroupParentId: parTopLevelManagementGroupParentId
    parLandingZoneMgAlzDefaultsEnable: parLandingZoneMgAlzDefaultsEnable
    parLandingZoneMgConfidentialEnable: parLandingZoneMgConfidentialEnable
    parLandingZoneMgChildren: parLandingZoneMgChildren
    parTelemetryOptOut: parTelemetryOptOut
  }
}

module roleDefinition '../alz-bicep-internal/infra-as-code/bicep/modules/customRoleDefinitions/customRoleDefinitions.bicep' = {
  scope: managementGroup(parTopLevelManagementGroupPrefix)
  name: 'customRoleDefinition'
  params: {
    parAssignableScopeManagementGroupId: parAssignableScopeManagementGroupId
    parTelemetryOptOut: parTelemetryOptOut
  }
  dependsOn: [
    managmentGroups
  ]
}

module
