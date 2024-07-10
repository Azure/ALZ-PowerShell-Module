<!-- markdownlint-disable first-line-h1 -->
### 2.2.1 Azure DevOps

You can choose to bootstrap with `bicep` or `terraform` skip to the relevant section below to do that.

Although you can just run `Deploy-Accelerator` and fill out the prompted inputs, we recommend creating an inputs file.  This will make it easier to run the accelerator more than once in order to refine your preferred configuration. In the following docs, we'll show that approach, but if you want to be prompted for inputs, just go ahead and run `Deploy-Accelerator` now.

#### 2.2.1.1 Azure DevOps with Bicep

1. Create a new folder on you local drive called `accelerator`.
1. Inside the accelerator create two folders called `config` and `output`. You'll store you input file inside config and the output folder will be the place that the accelerator stores files while it works.
1. Inside the `config` folder create a new file called `inputs.yaml`. You can use `json` if you prefer, but our examples here are `yaml`.

    ```plaintext
    📂accelerator
    ┣ 📂config
    ┃ ┗ 📜inputs.yaml
    ┗ 📂output
    ```

1. Open your `inputs.yaml` file in Visual Studio Code (or your preferred editor) and copy the content from [inputs-azure-devops-bicep.yaml][example_powershell_inputs_azure_devops_bicep] into that file.
1. Check through the file and update each input as required. It is mandatory to update items with placeholders surrounded by angle brackets `<>`:

    | Category | Input | Placeholder | Description |
    | --- | --- | --- | --- |
    | Basic | `iac` | `bicep` | This is the choice of `bicep` or `terraform`. Keep this as `bicep` for this example. |
    | Basic | `bootstrap` | `alz_azuredevops` | This is the choice of Version Control System. Keep this as `alz_azuredevops` for this example. |
    | Basic | `starter` | `complete` | This is the choice of [Starter Modules][wiki_starter_modules], which is the baseline configuration you want for your Azure landing zone. Keep this as `complete` for this example. This also determines the second set of inputs you'll be prompted for. |
    | Shared Interface | `root_parent_management_group_id` | `""` | This is the id of the management group that will be the parent of the management group structure created by the accelerator. If you are using the `Tenant Root Group` management group, you leave this as an empty string `""` or supply the tenant id. |
    | Shared Interface | `subscription_id_management` | `<management-subscription-id>` | Replace `<management-subscription-id>` with the id of the management subscription you created in the previous phase. |
    | Shared Interface | `subscription_id_identity` | `<identity-subscription-id>` | Replace `<identity-subscription-id>` with the id of the identity subscription you created in the previous phase. |
    | Shared Interface | `subscription_id_connectivity` | `<connectivity-subscription-id>` | Replace `<connectivity-subscription-id>` with the id of the connectivity subscription you created in the previous phase. |
    | Bootstrap | `azure_devops_personal_access_token` | `<token-1>` | Replace `<token-1>` with the `token-1` Azure DevOps PAT you generated in a previous step. |
    | Bootstrap | `azure_devops_agents_personal_access_token` | `<token-2>` | Replace `<token-2>` with the `token-2` Azure DevOps PAT you generated in the previous step specifically for the self-hosted agents. This only applies if you have `use_self_hosted_agents` set to `true`. You can set this to an empty string `""` if you are not using self-hosted agents. |
    | Bootstrap | `azure_devops_organization_name` | `<azure-devops-organization>` | Replace `<azure-devops-organization>` with the name of your Azure DevOps organization. This is the section of the url after `dev.azure.com` or before `.visualstudio.com`. E.g. enter `my-org` for `https://dev.azure.com/my-org`. |
    | Bootstrap | `use_separate_repository_for_pipeline_templates` | `true` | Determine whether to create a separate repository to store pipeline templates as an extra layer of security. Set to `false` if you don't wish to secure your pipeline templates by using a separate repository. This will default to `true`. |
    | Bootstrap | `bootstrap_location` | `<region>` | Replace `<region>` with the Azure region where you would like to deploy the bootstrap resources in Azure. This field expects the `name` of the region, such as `uksouth`. You can find a full list of names by running `az account list-locations -o table`. |
    | Bootstrap | `bootstrap_subscription_id` | `<bootstrap-subscription-id>` | Replace `<subscription-id>` with the id of the subscription in which you would like to deploy the bootstrap resources in Azure. If left blank, the subscription you are connected to via `az login` will be used. In most cases this is the management subscription, but you can specifiy a separate subscription if you prefer. |
    | Bootstrap | `service_name` | `alz` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-<service_name>-mgmt-uksouth-001`. We recommend using `alz` for this. |
    | Bootstrap | `environment_name` | `mgmt` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-alz-<environment_name>-uksouth-001`. We recommend using `mgmt` for this. |
    | Bootstrap | `postfix_number` | `1` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-alz-mgmt-uksouth-<postfix_number>`. We recommend using `1` for this. |
    | Bootstrap | `azure_devops_use_organisation_legacy_url` | `false` | If you have not migrated to the modern url (still using `https://<organization_name>.visualstudio.com`) for your Azure DevOps organisation, then set this to `true`. |
    | Bootstrap | `azure_devops_create_project` | `true` | If you have an existing project you want to use rather than creating a new one, select `true`. We recommend creating a new project to ensure it is isolated by a strong security boundary. |
    | Bootstrap | `azure_devops_project_name` | `<azure-devops-project-name>` | Replace `<azure-devops-project-name>` with the name of the Azure DevOps project to create or the name of an existing project if you set `azure_devops_create_project` to `false`. |
    | Bootstrap | `use_self_hosted_agents` | `true` | This controls if you want to deploy self-hosted agents. This will default to `true`. |
    | Bootstrap | `use_private_networking` | `true` | This controls whether private networking is deployed for your self-hosted agents and storage account. This only applies if you have `use_self_hosted_agents` set to `true`. This defaults to `true`. |
    | Bootstrap | `allow_storage_access_from_my_ip` | `false` | This is not relecant to Bicep and we'll remove the need to specify it later, leave it set to `false`. |
    | Bootstrap | `apply_approvers` | `<email-address-list>` | This is a list of service principal names (SPN) of people you wish to be in the group that approves apply of the Azure landing zone module. This is a comma-separated list like `abc@xyz.com,def@xyz.com,ghi@xyz.com`. You may need to check what the SPN is prior to filling this out as it can vary based on identity provider. Use empty string `""` to disable approvals. |
    | Bootstrap | `create_branch_policies` | `true` | This controls whether to create branch policies for the repository. This defaults to `true`. |

1. Now head over to your chosen starter module documentation to get the specific inputs for that module. Come back here when you are done.
    1. [Bicep Complete Starter Module][wiki_starter_module_bicep_complete]
1. In your PowerShell Core (pwsh) terminal run the module:

    ```pwsh
    # Windows (adjust the paths to match your setup)
    Deploy-Accelerator -inputs "c:\accelerator\inputs\input.yaml" -output "c:\accelerator\output"

    # Linux/Mac (adjust the paths to match your setup)
    Deploy-Accelerator -inputs "~/accelerator/inputs/input.yaml" -output "~/accelerator/output"
    ```

1. You will see a Terraform `init` and `apply` happen.
1. There will be a pause after the `plan` phase you allow you to validate what is going to be deployed.
1. If you are happy with the plan, then type `yes` and hit enter.
1. The Terraform will `apply` and your environment will be bootstrapped.

#### 2.2.1.2 Azure DevOps with Terraform

1. Create a new folder on you local drive called `accelerator`.
1. Inside the accelerator create two folders called `config` and `output`. You'll store you input file inside config and the output folder will be the place that the accelerator stores files while it works.
1. Inside the `config` folder create a new file called `inputs.yaml`. You can use `json` if you prefer, but our examples here are `yaml`.

    ```plaintext
    📂accelerator
    ┣ 📂config
    ┃ ┗ 📜inputs.yaml
    ┗ 📂output
    ```

1. Open your `inputs.yaml` file in Visual Studio Code (or your preferred editor) and copy the content from [inputs-azure-devops-terraform.yaml][example_powershell_inputs_azure_devops_terraform] into that file.
1. Check through the file and update each input as required. It is mandatory to update items with placeholders surrounded by angle brackets `<>`:

    | Category | Input | Placeholder | Description |
    | --- | --- | --- | --- |
    | Basic | `iac` | `terraform` | This is the choice of `bicep` or `terraform`. Keep this as `terraform` for this example. |
    | Basic | `bootstrap` | `alz_azuredevops` | This is the choice of Version Control System. Keep this as `alz_azuredevops` for this example. |
    | Basic | `starter` | `complete` | This is the choice of [Starter Modules][wiki_starter_modules], which is the baseline configuration you want for your Azure landing zone. Choose `complete`, `hubnetworking` or `basic` for this example. This also determines the second set of inputs you'll be prompted for. |
    | Shared Interface | `root_parent_management_group_id` | `""` | This is the id of the management group that will be the parent of the management group structure created by the accelerator. If you are using the `Tenant Root Group` management group, you leave this as an empty string `""` or supply the tenant id. |
    | Shared Interface | `subscription_id_management` | `<management-subscription-id>` | Replace `<management-subscription-id>` with the id of the management subscription you created in the previous phase. |
    | Shared Interface | `subscription_id_identity` | `<identity-subscription-id>` | Replace `<identity-subscription-id>` with the id of the identity subscription you created in the previous phase. |
    | Shared Interface | `subscription_id_connectivity` | `<connectivity-subscription-id>` | Replace `<connectivity-subscription-id>` with the id of the connectivity subscription you created in the previous phase. |
    | Bootstrap | `azure_devops_personal_access_token` | `<token-1>` | Replace `<token-1>` with the `token-1` Azure DevOps PAT you generated in a previous step. |
    | Bootstrap | `azure_devops_agents_personal_access_token` | `<token-2>` | Replace `<token-2>` with the `token-2` Azure DevOps PAT you generated in the previous step specifically for the self-hosted agents. This only applies if you have `use_self_hosted_agents` set to `true`. You can set this to an empty string `""` if you are not using self-hosted agents. |
    | Bootstrap | `azure_devops_organization_name` | `<azure-devops-organization>` | Replace `<azure-devops-organization>` with the name of your Azure DevOps organization. This is the section of the url after `dev.azure.com` or before `.visualstudio.com`. E.g. enter `my-org` for `https://dev.azure.com/my-org`. |
    | Bootstrap | `use_separate_repository_for_pipeline_templates` | `true` | Determine whether to create a separate repository to store pipeline templates as an extra layer of security. Set to `false` if you don't wish to secure your pipeline templates by using a separate repository. This will default to `true`. |
    | Bootstrap | `bootstrap_location` | `<region>` | Replace `<region>` with the Azure region where you would like to deploy the bootstrap resources in Azure. This field expects the `name` of the region, such as `uksouth`. You can find a full list of names by running `az account list-locations -o table`. |
    | Bootstrap | `bootstrap_subscription_id` | `<bootstrap-subscription-id>` | Replace `<subscription-id>` with the id of the subscription in which you would like to deploy the bootstrap resources in Azure. If left blank, the subscription you are connected to via `az login` will be used. In most cases this is the management subscription, but you can specifiy a separate subscription if you prefer. |
    | Bootstrap | `service_name` | `alz` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-<service_name>-mgmt-uksouth-001`. We recommend using `alz` for this. |
    | Bootstrap | `environment_name` | `mgmt` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-alz-<environment_name>-uksouth-001`. We recommend using `mgmt` for this. |
    | Bootstrap | `postfix_number` | `1` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-alz-mgmt-uksouth-<postfix_number>`. We recommend using `1` for this. |
    | Bootstrap | `azure_devops_use_organisation_legacy_url` | `false` | If you have not migrated to the modern url (still using `https://<organization_name>.visualstudio.com`) for your Azure DevOps organisation, then set this to `true`. |
    | Bootstrap | `azure_devops_create_project` | `true` | If you have an existing project you want to use rather than creating a new one, select `true`. We recommend creating a new project to ensure it is isolated by a strong security boundary. |
    | Bootstrap | `azure_devops_project_name` | `<azure-devops-project-name>` | Replace `<azure-devops-project-name>` with the name of the Azure DevOps project to create or the name of an existing project if you set `azure_devops_create_project` to `false`. |
    | Bootstrap | `use_self_hosted_agents` | `true` | This controls if you want to deploy self-hosted agents. This will default to `true`. |
    | Bootstrap | `use_private_networking` | `true` | This controls whether private networking is deployed for your self-hosted agents and storage account. This only applies if you have `use_self_hosted_agents` set to `true`. This defaults to `true`. |
    | Bootstrap | `allow_storage_access_from_my_ip` | `false` | This controls whether to allow access to the storage account from your IP address. This is only needed for trouble shooting. This only applies if you have `use_private_networking` set to `true`. This defaults to `false`. |
    | Bootstrap | `apply_approvers` | `<email-address-list>` | This is a list of service principal names (SPN) of people you wish to be in the group that approves apply of the Azure landing zone module. This is a comma-separated list like `abc@xyz.com,def@xyz.com,ghi@xyz.com`. You may need to check what the SPN is prior to filling this out as it can vary based on identity provider. Use empty string `""` to disable approvals. |
    | Bootstrap | `create_branch_policies` | `true` | This controls whether to create branch policies for the repository. This defaults to `true`. |

1. Now head over to your chosen starter module documentation to get the specific inputs for that module. Come back here when you are done.
    1. [Terraform Basic Starter Module][wiki_starter_module_terraform_basic]: Management groups and policies.
    1. [Terraform Hub Networking Starter Module][wiki_starter_module_terraform_hubnetworking]: Management groups, policies and hub networking.
    1. [Terraform Complete Starter Module][wiki_starter_module_terraform_complete]: Management groups, policies, hub networking with fully custom configuration.
1. In your PowerShell Core (pwsh) terminal run the module:

    ```pwsh
    # Windows (adjust the paths to match your setup)
    Deploy-Accelerator -inputs "c:\accelerator\inputs\input.yaml" -output "c:\accelerator\output"

    # Linux/Mac (adjust the paths to match your setup)
    Deploy-Accelerator -inputs "~/accelerator/inputs/input.yaml" -output "~/accelerator/output"
    ```

1. You will see a Terraform `init` and `apply` happen.
1. There will be a pause after the `plan` phase you allow you to validate what is going to be deployed.
1. If you are happy with the plan, then type `yes` and hit enter.
1. The Terraform will `apply` and your environment will be bootstrapped.

## Next Steps

Now head to [Phase 3][wiki_quick_start_phase_3].

 [//]: # (************************)
 [//]: # (INSERT LINK LABELS BELOW)
 [//]: # (************************)

[wiki_starter_modules]:                             %5BUser-Guide%5D-Starter-Modules "Wiki - Starter Modules"
[wiki_starter_module_bicep_complete]:               %5BUser-Guide%5D-Starter-Module-Bicep-Complete "Wiki - Starter Modules - Bicep Complete"
[wiki_starter_module_terraform_basic]:              %5BUser-Guide%5D-Starter-Module-Terraform-Basic "Wiki - Starter Modules - Terraform Basic"
[wiki_starter_module_terraform_hubnetworking]:      %5BUser-Guide%5D-Starter-Module-Terraform-HubNetworking "Wiki - Start Modules - Terraform Hub Networking"
[wiki_starter_module_terraform_complete]:           %5BUser-Guide%5D-Starter-Module-Terraform-Complete "Wiki - Starter Modules - Terraform Complete"
[wiki_quick_start_phase_3]:                         %5BUser-Guide%5D-Quick-Start-Phase-3 "Wiki - Quick Start - Phase 3"
[example_powershell_inputs_azure_devops_bicep]:     examples/powershell-inputs/inputs-azure-devops-bicep.yaml "Example - PowerShell Inputs - Azure DevOps - Bicep"
[example_powershell_inputs_azure_devops_terraform]: examples/powershell-inputs/inputs-azure-devops-terraform.yaml "Example - PowerShell Inputs - Azure DevOps - Terraform"
