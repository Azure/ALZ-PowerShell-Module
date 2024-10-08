<!-- markdownlint-disable first-line-h1 -->
The `complete_multi_region` starter module provides full customization of the Azure Landing Zone. It is multi-regional by default and can support 1 or more regions.

The ALZ PowerShell Module can accept multiple input files and we recommend using a separate file for the `complete_multi_region` starter module. This allows you to more easily manage and maintain your configuration files.

## Inputs

The following tables describe the inputs required for the `complete_multi_region` starter module. Depending on you choice of networking technology, you will need to supply the relevant inputs.

### Shared Inputs

| Input | Placeholder | Description |
| - | -- | --- |
| `management_settings_es` | `{}` | This is the management resource configuration for the ES (Enterprise Scale) versions of the management modules. Full details of the inputs can be seen [here](https://registry.terraform.io/modules/Azure/caf-enterprise-scale/azurerm/latest) |
| `connectivity_type` | `hub_and_spoke_vnet` | This is the choice of networking technology. Allowed values are `hub_and_spoke_vnet`, `virtual_wan` or `none`. |
| `connectivity_resource_groups` | `{}` | The resource groups used by the connectivity resources must be specified here. See the example files for usage. |
| ~~`management_use_avm`~~ | `false` | [NOTE: This variable will be implemented in a future version, setting to `true` will result in an error] This input is to specify to use the AVM (Azure Verified Modules) versions of the management modules. Defaults to `false`. |
| ~~`management_settings_avm`~~ | `{}` | [NOTE: This variable will be implemented in a future version] This is the management resource configuration for the AVM (Azure Verified Modules) versions of the management modules. |

### Hub and Spoke Virtual Network Inputs

| Input | Placeholder | Description |
| - | -- | --- |
| `hub_and_spoke_vnet_settings` | `{}` | This is for configuring global resources, such as the DDOS protection plan. See the example files for usage. |
| `hub_and_spoke_vnet_virtual_networks` | `{}` | This is the details configuration of each region for the hub networks. There are three top level components for each region: `hub_virtual_network`, `virtual_network_gateways` and `private_dns_zones`. Detailed information for `hub_virtual_network` inputs can be found [here](https://registry.terraform.io/modules/Azure/avm-ptn-hubnetworking). Detailed information for `virtual_network_gateways` can be found [here](https://registry.terraform.io/modules/Azure/avm-ptn-vnetgateway/azurerm/latest). See the example files for usage. |

### Virtual WAN Inputs

| Input | Placeholder | Description |
| - | -- | --- |
| `virtual_wan_settings` | `{}` | This is for configuring global resources, such as the Virtual WAN and DDOS protection plan. See the example files for usage. |
| `virtual_wan_virtual_hubs` | `{}` | This is the details configuration of each region for the virtual hubs. There are three top level components for each region: `hub`, `firewall` and `private_dns_zones`. Detailed information for `hub` and `firewall` inputs can be found [here](hhttps://registry.terraform.io/modules/Azure/avm-ptn-virtualwan/azurerm/latest). See the example files for usage. |

Example ALZ PowerShell input files can be found here:

- [inputs-azure-devops-terraform-complete-multi-region.yaml][example_powershell_inputs_azure_devops_terraform_complete_multi_region]
- [inputs-github-terraform-complete-multi-region.yaml][example_powershell_inputs_github_terraform_complete_multi_region]
- [inputs-local-terraform-complete-multi-region.yaml][example_powershell_inputs_local_terraform_complete_multi_region]

Example network technology specific input files can be found here:

- Multi region hub and spoke virtual network: [config-hub-and-spoke-vnet-multi-region.yaml][example_starter_module_complete_config_hub_spoke_multi_region]
- Multi region virtual WAN: [config-virtual-wan-multi-region.yaml][example_starter_module_complete_config_vwan_multi_region]
- Single region hub and spoke virtual network: [config-hub-and-spoke-vnet-single-region.yaml][example_starter_module_complete_config_hub_spoke_single_region]
- Single region virtual WAN: [config-virtual-wan-single-region.yaml][example_starter_module_complete_config_vwan_single_region]

## Further details on the Complete Multi Region Starter Module and config file

The example config files have helpful templated variables such as `starter_location_##` and `root_parent_management_group_id` which get prompted for during the ALZ PowerShell Module run. Alternatively, you can opt to not use the templated variables and hard-code the values in your config file.

> **Note:** We currently use the `caf-enterprise-scale` module for management groups and policies, and the Azure Verified Modules for connectivity resources.

### High Level Design

![Alt text](./media/starter-module-hubnetworking.png)

### Terraform Modules

The following modules are composed together in the `complete_multi_region` starter module.

#### `caf-enterprise-scale`

The `caf-enterprise-scale` module is used to deploy the management group hierarchy, policy assignments and management resources. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-caf-enterprise-scale).

#### `avm-ptn-hubnetworking`

The `avm-ptn-hubnetworking` module is used to deploy connectivity resources such as Virtual Networks and Firewalls.
This module can be extended to deploy multiple Virtual Networks at scale, Route Tables, and Resource Locks. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-ptn-hu).

#### `avm-ptn-vnetgateway`

The `avm-ptn-vnetgateway` module is used to deploy a Virtual Network Gateway inside your Virtual Network. Further configuration can be added (depending on requirements) to deploy Local Network Gateways, configure Virtual Network Gateway Connections, deploy ExpressRoute Gateways, and more. Additional information on the module can be found [here](https://github.com/Azure/terraform-azurerm-avm-ptn-vnetgateway).

#### `avm-ptn-vwan`

The `avm-ptn-vwan` module is used to deploy a Virtual WAN. Further configuration can be added (depending on requirements) to deploy VPN Sites, configure VPN Connections, and more. Additional information on the module can be found [here](https://github.com/Azure/terraform-azurerm-avm-ptn-vwan).

#### `avm-ptn-network-private-link-private-dns-zones`

The `avm-ptn-network-private-link-private-dns-zones` module is used to deploy Private DNS Zones for Private Link Services. Further configuration can be added depending on requirements. Additional information on the module can be found [here](https://github.com/Azure/terraform-azurerm-avm-ptn-network-private-link-private-dns-zones).

 [//]: # (************************)
 [//]: # (INSERT LINK LABELS BELOW)
 [//]: # (************************)

[example_starter_module_complete_config_hub_spoke_single_region]: https://raw.githubusercontent.com/wiki/Azure/ALZ-PowerShell-Module/examples/starter-module-config/complete-multi-region/config-hub-and-spoke-vnet-single-region.yaml "Example - Starter Module Config - Complete - Hub and Spoke VNet Single Region"
[example_starter_module_complete_config_vwan_single_region]: https://raw.githubusercontent.com/wiki/Azure/ALZ-PowerShell-Module/examples/starter-module-config/complete-multi-region/config-virtual-wan-single-region.yaml "Example - Starter Module Config - Complete - Virtual WAN Single Region"
[example_starter_module_complete_config_hub_spoke_multi_region]: https://raw.githubusercontent.com/wiki/Azure/ALZ-PowerShell-Module/examples/starter-module-config/complete-multi-region/config-hub-and-spoke-vnet-multi-region.yaml "Example - Starter Module Config - Complete - Hub and Spoke VNet Multi Region"
[example_starter_module_complete_config_vwan_multi_region]: https://raw.githubusercontent.com/wiki/Azure/ALZ-PowerShell-Module/examples/starter-module-config/complete-multi-region/config-virtual-wan-multi-region.yaml "Example - Starter Module Config - Complete - Virtual WAN Multi Region"
[example_powershell_inputs_azure_devops_terraform_complete_multi_region]:     examples/powershell-inputs/inputs-azure-devops-terraform-complete-multi-region.yaml "Example - PowerShell Inputs - Azure DevOps - Terraform - Complete Multi Region"
[example_powershell_inputs_github_terraform_complete_multi_region]:     examples/powershell-inputs/inputs-github-terraform-complete-multi-region.yaml "Example - PowerShell Inputs - GitHub - Terraform - Complete Multi Region"
[example_powershell_inputs_local_terraform_complete_multi_region]:     examples/powershell-inputs/inputs-local-terraform-complete-multi-region.yaml "Example - PowerShell Inputs - Local - Terraform - Complete Multi Region"
