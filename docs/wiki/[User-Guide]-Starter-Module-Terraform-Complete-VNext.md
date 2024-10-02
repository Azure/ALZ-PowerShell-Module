<!-- markdownlint-disable first-line-h1 -->
> **WARNING:** The Complete vNext starter module is a work in progress. Do not use this for any production workloads.

The `complete_vnext` starter module provides full customization of the Azure Landing Zone using the `config.yaml` file. The `config.yaml` file provides the ability to enable and disable modules, configure module inputs and outputs, and configure module resources.
A custom `config.yaml` file can be passed to the `configuration_file_path` argument of the ALZ PowerShell Module. This allows you to firstly design your Azure Landing Zone, and then deploy it.

If not specified, the default `config.yaml` file will be used, which can be seen [here](https://github.com/Azure/alz-terraform-accelerator/blob/main/templates/complete_vnext/config.yaml).

Example input files can be found here:

- [inputs-azure-devops-terraform-complete_vnext.yaml][example_powershell_inputs_azure_devops_terraform_complete_vnext]
- [inputs-github-terraform-complete_vnext.yaml][example_powershell_inputs_github_terraform_complete_vnext]
- [inputs-local-terraform-complete_vnext.yaml][example_powershell_inputs_local_terraform_complete_vnext]

The following table describes the inputs required for the `complete_vnext` starter module.

| Input | Placeholder | Description |
| - | -- | --- |
| `configuration_file_path` | `<configuration-file-path>` | This is the absolute path to the configuration file. E.g. `c:\my-config\config.yaml` or `~/my-config/config.yaml`. For YAML on Windows you will need to escape the `\`, i.e. `c:\\my-config\\config.yaml`. |
| `default_postfix` | `<postfix>` | This is the default postfix used for resource names. |

## Further details on the Complete Starter Module and config file

The `config.yaml` file also comes with helpful templated variables such as `default_location` and `root_parent_management_group_id` which get prompted for during the ALZ PowerShell Module run. Alternatively, you can opt to not use the templated variables and hard-code the values in the `config.yaml` file.

> **Note:** We recommend that you use the `caf-enterprise-scale` module for management groups and policies, and the `hubnetworking` module for connectivity resources. However, connectivity resources can be deployed using the `caf-enterprise-scale` module if you desire.

The schema for the `config.yaml` is documented here - [Configuration YAML Schema][wiki_yaml_schema_reference].

### High Level Design

![Alt text](./media/starter-module-hubnetworking.png)

### Terraform Modules

#### `caf-enterprise-scale`

The `caf-enterprise-scale` module is used to deploy the management group hierarchy, policy assignments and management resources. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-caf-enterprise-scale).

#### `hubnetworking`

The `hubnetworking` module is used to deploy connectivity resources such as Virtual Networks and Firewalls.
This module can be extended to deploy multiple Virtual Networks at scale, Route Tables, and Resource Locks. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-hubnetworking).

#### `avm-ptn-vnetgateway`

The `avm-ptn-vnetgateway` module is used to deploy a Virtual Network Gateway inside your Virtual Network. Further configuration can be added (depending on requirements) to deploy Local Network Gateways, configure Virtual Network Gateway Connections, deploy ExpressRoute Gateways, and more. Additional information on the module can be found [here](https://github.com/Azure/terraform-azurerm-avm-ptn-vnetgateway).

#### `avm-ptn-vwan`

The `avm-ptn-vwan` module is used to deploy a Virtual WAN. Further configuration can be added (depending on requirements) to deploy VPN Sites, configure VPN Connections, and more. Additional information on the module can be found [here](https://github.com/Azure/terraform-azurerm-avm-ptn-vwan).

#### Design your Azure Landing Zone through a custom config file

Create a custom yaml config to tailor to your needs, for example an Azure Landing Zone with a three-region mesh:

- Example config file for hub and spoke: [config-hub-spoke.yaml][example_starter_module_complete_vnext_config_hub_spoke]
- Example config file for Virtual WAN: [config-vwan.yaml][example_starter_module_complete_vnext_config_vwan]

 [//]: # (************************)
 [//]: # (INSERT LINK LABELS BELOW)
 [//]: # (************************)

[wiki_yaml_schema_reference]: %5BUser-Guide%5D-YAML-Schema-Reference "Wiki - YAML Schema Reference"
[example_starter_module_complete_vnext_config_hub_spoke]: examples/starter-module-config/complete_vnext/config-hub-spoke.yaml "Example - Starter Module Config - Complete - Hub and Spoke"
[example_starter_module_complete_vnext_config_vwan]: examples/starter-module-config/complete_vnext/config-vwan.yaml "Example - Starter Module Config - Complete - Virtual WAN"
[example_powershell_inputs_azure_devops_terraform_complete_vnext]:     examples/powershell-inputs/inputs-azure-devops-terraform-complete_vnext.yaml "Example - PowerShell Inputs - Azure DevOps - Terraform - Complete vNext"
[example_powershell_inputs_github_terraform_complete_vnext]:     examples/powershell-inputs/inputs-github-terraform-complete_vnext.yaml "Example - PowerShell Inputs - GitHub - Terraform - Complete vNext"
[example_powershell_inputs_local_terraform_complete_vnext]:     examples/powershell-inputs/inputs-local-terraform-complete_vnext.yaml "Example - PowerShell Inputs - Local - Terraform - Complete vNext"
