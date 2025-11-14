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
            version = "~> 2.0"
        }
    }
    }

    module "regions" {
    source                    = "Azure/avm-utl-regions/azurerm"
    version                   = "0.5.2"
    use_cached_data           = false
    availability_zones_filter = false
    recommended_filter        = false
    }

    locals {
    regions = { for region in module.regions.regions_by_name : region.name => {
        display_name = region.display_name
        zones        = region.zones == null ? [] : [for zone in region.zones : tostring(zone)]
        }
    }
    }

    output "regions_and_zones" {
    value = local.regions
    }
'@

    $regionFolder = Join-Path $toolsPath "azure-regions"
    if (Test-Path $regionFolder) {
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

    foreach ($region in $regionsAndZones.PSObject.Properties) {
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
