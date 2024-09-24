function Get-AzureRegionData {
    param(
        [Parameter(Mandatory = $false)]
        [string]$toolsPath = ".\region"
    )

    $terraformCode = @'
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
'@

    $regionFolder = Join-Path $toolsPath "azure-regions"
    if(Test-Path $regionFolder) {
        Remove-Item $regionFolder -Recurse -Force
    }

    New-Item $regionFolder -ItemType "Directory"

    $regionCodeFileName = Join-Path $regionFolder "main.tf"
    $terraformCode | Out-File $regionCodeFileName -Force

    $outputFilePath = Join-Path $regionFolder "output.json"

    Invoke-Terraform -moduleFolderPath $regionFolder -autoApprove -output "regions_and_zones" -outputFilePath $outputFilePath -silent

    $json = Get-Content $outputFilePath
    $regionsAndZones = ConvertFrom-Json $json

    $zonesSupport = @()
    $supportedRegions = @()

    foreach($region in $regionsAndZones.PSObject.Properties) {
        $supportedRegions += $region.Name
        $zonesSupport += @{
            region = $region.Name
            zones  = $region.Value.zones
        }
    }

    return @{
        zonesSupport     = $zonesSupport
        supportedRegions = $supportedRegions
    }
}