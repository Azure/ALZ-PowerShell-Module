<!-- markdownlint-disable first-line-h1 -->
The `complete` starter module is currently the only option available for Bicep.

Example input files can be found here:

- [inputs-azure-devops-bicep.yaml][example_powershell_inputs_azure_devops_bicep]
- [inputs-github-bicep.yaml][example_powershell_inputs_github_bicep]

The following table describes the inputs required for the `complete` starter module.

| Input | Placeholder | Description |
| - | -- | --- |
| `Prefix` | `landing-zone` | This is the defaut prefix for names of resources and management groups. |
| `Environment` | `live` | The environment name for the landing zone. This can be any lower case string. (e.g. `live` or `canary`)  |
| `networkType` | `hubNetworking` | The type of network configuration to deploy. Currently only `hubNetworking`, `vwanConnectivity` or `none` are supported. |
| `SecurityContact` | `<email-address>` | The email address of the security contact for the landing zone. |

 [//]: # (************************)
 [//]: # (INSERT LINK LABELS BELOW)
 [//]: # (************************)

[example_powershell_inputs_azure_devops_bicep]:     examples/powershell-inputs/inputs-azure-devops-bicep.yaml "Example - PowerShell Inputs - Azure DevOps - Bicep"
[example_powershell_inputs_github_bicep]:     examples/powershell-inputs/inputs-github-bicep.yaml "Example - PowerShell Inputs - GitHub - Bicep"
