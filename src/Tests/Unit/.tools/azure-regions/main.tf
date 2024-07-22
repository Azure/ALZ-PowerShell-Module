terraform {
  required_providers {
    azapi = {
        source  = "azure/azapi"
        version = "~> 1.14"
    }
  }
}

data "azapi_client_config" "current" {}

data "azapi_resource_action" "locations" {
  type                   = "Microsoft.Resources/subscriptions@2022-12-01"
  action                 = "locations"
  method                 = "GET"
  resource_id            = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  response_export_values = ["value"]
}

locals {
  regions = { for region in jsondecode(data.azapi_resource_action.locations.output).value : region.name => {
      display_name = region.displayName
      zones = try([ for zone in region.availabilityZoneMappings : zone.logicalZone ], [])
    } if region.metadata.regionType == "Physical"
  }
}

output "regions_and_zones" {
  value = local.regions
}
