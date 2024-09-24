<!-- markdownlint-disable first-line-h1 -->
The `basic` starter module deploys the management group hierarchy, management resources and policies only.

Example input files can be found here:

- [inputs-azure-devops-terraform-basic.yaml][example_powershell_inputs_azure_devops_terraform_basic]
- [inputs-github-terraform-basic.yaml][example_powershell_inputs_github_terraform_basic]
- [inputs-local-terraform-basic.yaml][example_powershell_inputs_local_terraform_basic]

The following table describes the inputs required for the `basic` starter module.

| Input | Placeholder | Description |
| - | -- | --- |
| `root_id` | `<id_prefix>` | This is the prefix for the ID of management groups. |
| `root_name` | `<name_prefix>` | This is the prefix for the name of management groups. |

 [//]: # (************************)
 [//]: # (INSERT LINK LABELS BELOW)
 [//]: # (************************)

[example_powershell_inputs_azure_devops_terraform_basic]:     examples/powershell-inputs/inputs-azure-devops-terraform-basic.yaml "Example - PowerShell Inputs - Azure DevOps - Terraform - Basic"
[example_powershell_inputs_github_terraform_basic]:     examples/powershell-inputs/inputs-github-terraform-basic.yaml "Example - PowerShell Inputs - GitHub - Terraform - Basic"
[example_powershell_inputs_local_terraform_basic]:     examples/powershell-inputs/inputs-local-terraform-basic.yaml "Example - PowerShell Inputs - Local - Terraform - Basic"
