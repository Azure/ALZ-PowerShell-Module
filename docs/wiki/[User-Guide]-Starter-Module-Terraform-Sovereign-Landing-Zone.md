<!-- markdownlint-disable first-line-h1 -->
The `sovereign_landing_zone` starter module provides full customization of the Sovereign Landing Zone (SLZ) using the `inputs.yaml` file. The `inputs.yaml` file provides the ability to enable and disable modules, configure module inputs and outputs, and configure module resources.
A custom `inputs.yaml` file can be passed to the `inputs` argument of the ALZ PowerShell Module. This allows you to firstly design your Azure Landing Zone, and then deploy it.

The default `inputs.yaml` file will need to be modified based off the documentation found [here][parameter_description_powershell_inputs_local_terraform_slz].

Default input files can be found here:

- [inputs-azure-devops-terraform-sovereign-landing-zone.yaml][example_powershell_inputs_azure_devops_terraform_sovereign_landing_zone]
- [inputs-github-terraform-sovereign-landing-zone.yaml][example_powershell_inputs_github_terraform_sovereign_landing_zone]
- [inputs-local-terraform-sovereign-landing-zone.yaml][example_powershell_inputs_local_terraform_sovereign_landing_zone]

The following table describes the inputs for the `sovereign_landing_zone` starter module.

| Input | Required | Type | Default Value | Description |
| - | -- | --- | ---- | ----- |
| `allowed_locations` | Required | List |  | This is a list of Azure regions all workloads running outside of the Confidential Management Group scopes are allowed to be deployed into. |
| `allowed_locations_for_confidential_computing` | Required | List |  | This is a list of Azure regions all workloads running inside of the Confidential Management Group scopes are allowed to be deployed into. |
| `az_firewall_policies_enabled` |  | Boolean | `true` | Set to `true` to deploy a default Azure Firewall Policy resource if `enable_firewall` is also `true`. |
| `apply_alz_archetypes_via_architecture_definition_template` |  | Boolean | `true` | This controls whether to apply the ALZ archetypes (polcy assignments) to the SLZ deployment. |
| `bastion_outbound_ssh_rdp_ports` |  | List | `["22", "3389"]` | List of outbound remote access ports to enable on the Azure Bastion NSG if `deploy_bastion` is also `true`. |
| `custom_subnets` |  | Map | See `inputs.yaml` for default object. | Map of subnets and their configurations to create within the hub network. |
| `customer` |  | String | `"Country/Region"` | Customer name to use when branding the compliance dashboard. |
| `customer_policy_sets` |  | Map | See the Custom Compliance section below for details. | Map of customer specified policy initiatives to apply alongside the SLZ. |
| `default_postfix` |  | String |  | Postfix value to append to all resources. |
| `default_prefix` | Required | String | `slz` | Prefix value to append to all resources. |
| `deploy_bastion` |  | Boolean | `true` | Set to `true` to deploy Azure Bastion within the hub network. |
| `deploy_ddos_protection` |  | Boolean | `true` | Set to `true` to deploy Azure DDoS Protection within the hub network. |
| `deploy_hub_network` |  | Boolean | `true` | Set to `true` to deploy the hub network. |
| `deploy_log_analytics_workspace` |  | Boolean | `true` | Set to `true` to deploy Azure Log Analytics Workspace. |
| `enable_firewall` |  | Boolean | `true` | Set to `true` to deploy Azure Firewall within the hub network. |
| `enable_telemetry` |  | Boolean | `true` | Set to `false` to opt out of telemetry tracking. We use telemetry data to understand usage rates to help prioritize future development efforts. |
| `express_route_gateway_config` |  | Map | `{name: "noconfigEr"}` | Leave as default to not deploy an ExpressRoute Gateway. See the Network Connectivity section below for details. |
| `hub_network_address_prefix` |  | CIDR | "10.20.0.0/16" | This is the CIDR to use for the hub network. |
| `landing_zone_management_group_children` |  | Map |  | See the Customize Application Landing Zones section below for details. |
| `log_analytics_workspace_retention_in_days` |  | Numeric | 365 | Number of days to retain logs in the Log Analytics Workspace. |
| `ms_defender_for_cloud_email_security_contact` |  | Email | `security_contact@replaceme.com` | Email address to use for Microsoft Defender for Cloud. |
| `policy_assignment_enforcement_mode` |  | String | `Default` | The enforcement mode to use for the Sovereign Baseline Policy initiatives. |
| `policy_effect` |  | String | `Deny` | The effect to use for the Sovereign Baseline Policy initiatives, when policies support multiple effects. |
| `policy_exemptions` |  | Map | See the Custom Compliance section below for details. | Map of customer specified policy exemptions to use alongside the SLZ. |
| `subscription_billing_scope` |  | String |  | Only required if you have not provided existing subscription IDs for management, connectivity, and identity. |
| `tags` |  | Map | See the Custom Tagging section below for details. | Set of tags to apply to all resources deployed. |
| `use_premium_firewall` |  | Boolean | `true` | Set to `true` to deploy Premium SKU of the Azure Firewall if `enable_firewall` is also `true`. |
| `vpn_gateway_config` |  | Map | `{name: "noconfigEr"}` | Leave as default to not deploy an VPN Gateway. See the Network Connectivity section below for details. |

Full parameter details can be found [here][parameter_description_powershell_inputs_local_terraform_slz].

## Further details on the Sovereign Landing Zone Starter Module

The Terraform-based deployment for the Sovereign Landing Zone (SLZ) provides an Enterprise Scale Landing Zone with equivalent compliance posture equal to that of our [Bicep implementation][bicep_implementation_slz]. There is not currently a migration path between the two implementations, however multiple landing zones can be created with either deployment technology in the same Azure tenant.

### High Level Design

![Alt text](./media/starter-module-microsoft_cloud_for_sovereignty.png)

### Terraform Modules

#### `alz-archetypes` and `slz-archetypes`

The `alz-archetypes` and `slz-archetypes` are different from Terraform modules, but are used to deploy the management group hierarchy, policy assignments and management resources including the sovereign baseline policies. For more information on the archetypes, view the [ALZ archetypes](https://github.com/Azure/Azure-Landing-Zones-Library/blob/main/platform/alz/) and the [SLZ archetypes](https://github.com/Azure/Azure-Landing-Zones-Library/blob/main/platform/slz/).

#### `subscription-vending`

The `subscription-vending` module is used to deploy the subscriptions and move them within the right management group scopes. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-lz-vending/tree/main/modules/subscription).

#### `hubnetworking`

The `hubnetworking` module is used to deploy the hub VNET, Azure Firewall , Route Tables, and other networking primitives into the connectivity subscription. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-ptn-hubnetworking).

#### `private-link`

The `private-link` module is used to deploy default private link private DNS Zones. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-ptn-network-private-link-private-dns-zones).

#### `alz-management`

The `alz-management` module is used to deploy a set of management resources such as those for centralized logging. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-ptn-alz-management).

#### `resource-group`

The `resource-group` module is used to deploy a variety of resource groups within the default subscriptions. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-res-resources-resourcegroup).

#### `portal-dashboard`

The `portal-dashboard` module is used to deploy the default compliance dashboard. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-res-portal-dashboard).

#### `azure-bastion`

The `azure-bastion` module is used to deploy Azure Bastion for remote access. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-res-network-bastionhost).

#### `firewall-policy`

The `firewall-policy` module is used to deploy a default Azure Firewall Policy for further configuration. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-res-network-firewallpolicy).

#### `ddos-protection`

The `ddos-protection` module is used to deploy a Standard SKU DDoS Protection Plan resource for network security. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-res-network-ddosprotectionplan).

#### `public-ip`

The `public-ip` module is used to deploy a Azure Public IP resoures for offerings that need inbound public internet access such as the VPN and ExpressRoute Gateways. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-res-network-publicipaddress).

#### `networksecuritygroup`

The `networksecuritygroup` module is used to deploy a default NSG for the Azure Bastion subnet to restrict ingress and egress network access. For more information on the module itself see [here](https://github.com/Azure/terraform-azurerm-avm-res-network-networksecuritygroup).

 [//]: # (************************)
 [//]: # (INSERT LINK LABELS BELOW)
 [//]: # (************************)

[example_powershell_inputs_azure_devops_terraform_sovereign_landing_zone]:               examples/powershell-inputs/inputs-azure-devops-terraform-sovereign_landing_zone.yaml "Example - PowerShell Inputs - Devops - Terraform - Sovereign Landing Zone"
[example_powershell_inputs_github_terraform_sovereign_landing_zone]:               examples/powershell-inputs/inputs-github-terraform-sovereign_landing_zone.yaml "Example - PowerShell Inputs - Local - Terraform - Sovereign Landing Zone"
[example_powershell_inputs_local_terraform_sovereign_landing_zone]:               examples/powershell-inputs/inputs-local-terraform-sovereign_landing_zone.yaml "Example - PowerShell Inputs - Local - Terraform - Sovereign Landing Zone"
[parameter_description_powershell_inputs_local_terraform_slz]: https://aka.ms/slz/terraform/params "Parameter Description - PowerShell Inputs - Local - Terraform - Sovereign Landing Zone"
[bicep_implementation_slz]:                                    https://aka.ms/slz/bicep "Sovereign Landing Zone (Bicep)"
