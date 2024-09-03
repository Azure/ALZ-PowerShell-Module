<!-- markdownlint-disable first-line-h1 -->
The `hubnetworking` starter module deploys the management group hierarchy, management resources, policies and hub networking.

Example input files can be found here:

- [inputs-azure-devops-terraform-hubnetworking.yaml][example_powershell_inputs_azure_devops_terraform_hubnetworking]
- [inputs-github-terraform-hubnetworking.yaml][example_powershell_inputs_github_terraform_hubnetworking]
- [inputs-local-terraform-hubnetworking.yaml][example_powershell_inputs_local_terraform_hubnetworking]

The following table describes the inputs required for the `hubnetworking` starter module.

| Input | Placeholder | Description |
| - | -- | --- |
| `root_id` | `<id_prefix>` | This is the prefix for the ID of management groups. |
| `root_name` | `<name_prefix>` | This is the prefix for the name of management groups. |
| `hub_virtual_network_address_prefix` | `<hub_virtual_network_address_prefix>` | This is the ip address prefix for the hub virtual network. This must be a valid CIDR, e.g. `10.0.0.0/16`. |
| `firewall_subnet_address_prefix` | `<firewall_subnet_address_prefix>` | This is the ip address prefix for the firewall subnet. This must be a valid CIDR, e.g. `10.0.0.0/24`. |
| `gateway_subnet_address_prefix` | `<gateway_subnet_address_prefix>` | This is the ip address prefix for the gateway subnet. This must be a valid CIDR, e.g. `10.0.1.0/24`. |
| `virtual_network_gateway_creation_enabled` | `true` | Determines whether or not to deploy the gateway. |

 [//]: # (************************)
 [//]: # (INSERT LINK LABELS BELOW)
 [//]: # (************************)

[example_powershell_inputs_azure_devops_terraform_hubnetworking]:     examples/powershell-inputs/inputs-azure-devops-terraform-hubnetworking.yaml "Example - PowerShell Inputs - Azure DevOps - Terraform - Hub Networking"
[example_powershell_inputs_github_terraform_hubnetworking]:     examples/powershell-inputs/inputs-github-terraform-hubnetworking.yaml "Example - PowerShell Inputs - GitHub - Terraform - Hub Networking"
[example_powershell_inputs_local_terraform_hubnetworking]:     examples/powershell-inputs/inputs-local-terraform-hubnetworking.yaml "Example - PowerShell Inputs - Local - Terraform - Hub Networking"
