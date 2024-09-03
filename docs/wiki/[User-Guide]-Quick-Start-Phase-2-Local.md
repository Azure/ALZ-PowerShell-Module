<!-- markdownlint-disable first-line-h1 -->
## 2.2.3 Local File System

You can choose to bootstrap with `bicep` or `terraform` skip to the relevant section below to do that.

Although you can just run `Deploy-Accelerator` and fill out the prompted inputs, we recommend creating an inputs file.  This will make it easier to run the accelerator more than once in order to refine your preferred configuration. In the following docs, we'll show that approach, but if you want to be prompted for inputs, just go ahead and run `Deploy-Accelerator` now.

### 2.2.3.1 Local File System with Bicep

1. Create a new folder on you local drive called `accelerator`.
1. Inside the accelerator create two folders called `config` and `output`. You'll store you input file inside config and the output folder will be the place that the accelerator stores files while it works.
1. Inside the `config` folder create a new file called `inputs.yaml`. You can use `json` if you prefer, but our examples here are `yaml`.

    ```pwsh
    # Windows
    New-Item -ItemType "file" c:\accelerator\config\inputs.yaml -Force
    New-Item  -ItemType "directory" c:\accelerator\output

    # Linux/Mac
    New-Item -ItemType "file" ~/accelerator/config/inputs.yaml -Force
    New-Item -ItemType "directory" ~/accelerator/output
    ```

    ```plaintext
    📂accelerator
    ┣ 📂config
    ┃ ┗ 📜inputs.yaml
    ┗ 📂output
    ```

1. Open your `inputs.yaml` file in Visual Studio Code (or your preferred editor) and copy the content from [inputs-local-bicep-complete.yaml][example_powershell_inputs_local_bicep_complete] into that file.
1. Check through the file and update each input as required. It is mandatory to update items with placeholders surrounded by angle brackets `<>`:

    | Input | Placeholder | Description |
    | - | -- | --- |
    | `iac` | `bicep` | This is the choice of `bicep` or `terraform`. Keep this as `bicep` for this example. |
    | `bootstrap` | `alz_local` | This is the choice of Version Control System. Keep this as `alz_local` for this example. |
    | `starter` | `complete` | This is the choice of [Starter Modules][wiki_starter_modules], which is the baseline configuration you want for your Azure landing zone. Keep this as `complete` for this example. This also determines the second set of inputs you'll be prompted for. |
    | `bootstrap_location` | `<region>` | Replace `<region>` with the Azure region where you would like to deploy the bootstrap resources in Azure. This field expects the `name` of the region, such as `uksouth`. You can find a full list of names by running `az account list-locations -o table`. |
    | `starter_location` | `<region>` | Replace `<region>` with the Azure region where you would like to deploy the starter module resources in Azure. This field expects the `name` of the region, such as `uksouth`. You can find a full list of names by running `az account list-locations -o table`. |
    | `root_parent_management_group_id` | `""` | This is the id of the management group that will be the parent of the management group structure created by the accelerator. If you are using the `Tenant Root Group` management group, you leave this as an empty string `""` or supply the tenant id. |
    | `subscription_id_management` | `<management-subscription-id>` | Replace `<management-subscription-id>` with the id of the management subscription you created in the previous phase. |
    | `subscription_id_identity` | `<identity-subscription-id>` | Replace `<identity-subscription-id>` with the id of the identity subscription you created in the previous phase. |
    | `subscription_id_connectivity` | `<connectivity-subscription-id>` | Replace `<connectivity-subscription-id>` with the id of the connectivity subscription you created in the previous phase. |
    | `target_directory` | `<target-directory>` | This is the directory where the ALZ module code will be created. This defaults a directory called `local` in the root of the accelerator directory if not supplied. |
    | `create_bootstrap_resources_in_azure` | `true` | This determines whether the bootstrap will create the bootstrap resources in Azure. This defaults to `true`. |
    | `bootstrap_subscription_id` | `""` | Enter the id of the subscription in which you would like to deploy the bootstrap resources in Azure. If left blank, the subscription you are connected to via `az login` will be used. In most cases this is the management subscription, but you can specifiy a separate subscription if you prefer. |
    | `service_name` | `alz` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-<service_name>-mgmt-uksouth-001`. We recommend using `alz` for this. |
    | `environment_name` | `mgmt` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-alz-<environment_name>-uksouth-001`. We recommend using `mgmt` for this. |
    | `postfix_number` | `1` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-alz-mgmt-uksouth-<postfix_number>`. We recommend using `1` for this. |

1. Now head over to your chosen starter module documentation to get the specific inputs for that module. Come back here when you are done.
    - [Bicep Complete Starter Module][wiki_starter_module_bicep_complete]
1. In your PowerShell Core (pwsh) terminal run the module:

    ```pwsh
    # Windows (adjust the paths to match your setup)
    Deploy-Accelerator -inputs "c:\accelerator\config\inputs.yaml" -output "c:\accelerator\output"

    # Linux/Mac (adjust the paths to match your setup)
    Deploy-Accelerator -inputs "~/accelerator/config/inputs.yaml" -output "~/accelerator/output"
    ```

1. You will see a Terraform `init` and `apply` happen.
1. There will be a pause after the `plan` phase you allow you to validate what is going to be deployed.
1. If you are happy with the plan, then type `yes` and hit enter.
1. The Terraform will `apply` and your environment will be bootstrapped.

### 2.2.3.2 Local File System with Terraform

1. Create a new folder on you local drive called `accelerator`.
1. Inside the accelerator create two folders called `config` and `output`. You'll store you input file inside config and the output folder will be the place that the accelerator stores files while it works.
1. Inside the `config` folder create a new file called `inputs.yaml`. You can use `json` if you prefer, but our examples here are `yaml`.

    ```pwsh
    # Windows
    New-Item -ItemType "file" c:\accelerator\config\inputs.yaml -Force
    New-Item -ItemType "directory" c:\accelerator\output
    ```

    ```pwsh
    # Linux/Mac
    New-Item -ItemType "file" ~/accelerator/config/inputs.yaml -Force
    New-Item -ItemType "directory" ~/accelerator/output
    ```

    ```plaintext
    📂accelerator
    ┣ 📂config
    ┃ ┗ 📜inputs.yaml
    ┗ 📂output
    ```

1. Open your `inputs.yaml` file in Visual Studio Code (or your preferred editor) and copy the content from the relevant input file for your chosen starter module:
    1. Basic - [inputs-local-terraform-basic.yaml][example_powershell_inputs_local_terraform_basic]
    1. Hub Networking - [inputs-local-terraform-hubnetworking.yaml][example_powershell_inputs_local_terraform_hubnetworking]
    1. Complete - [inputs-local-terraform-complete.yaml][example_powershell_inputs_local_terraform_complete]
1. Check through the file and update each input as required. It is mandatory to update items with placeholders surrounded by angle brackets `<>`:

    | Input | Placeholder | Description |
    | - | -- | --- |
    | `iac` | `terraform` | This is the choice of `bicep` or `terraform`. Keep this as `terraform` for this example. |
    | `bootstrap` | `alz_local` | This is the choice of Version Control System. Keep this as `alz_local` for this example. |
    | `starter` | `complete` | This is the choice of [Starter Modules][wiki_starter_modules], which is the baseline configuration you want for your Azure landing zone. Choose `complete`, `hubnetworking` or `basic` for this example. This also determines the second set of inputs you'll be prompted for. |
    | `bootstrap_location` | `<region>` | Replace `<region>` with the Azure region where you would like to deploy the bootstrap resources in Azure. This field expects the `name` of the region, such as `uksouth`. You can find a full list of names by running `az account list-locations -o table`. |
    | `starter_location` | `<region>` | Replace `<region>` with the Azure region where you would like to deploy the starter module resources in Azure. This field expects the `name` of the region, such as `uksouth`. You can find a full list of names by running `az account list-locations -o table`. |
    | `root_parent_management_group_id` | `""` | This is the id of the management group that will be the parent of the management group structure created by the accelerator. If you are using the `Tenant Root Group` management group, you leave this as an empty string `""` or supply the tenant id. |
    | `subscription_id_management` | `<management-subscription-id>` | Replace `<management-subscription-id>` with the id of the management subscription you created in the previous phase. |
    | `subscription_id_identity` | `<identity-subscription-id>` | Replace `<identity-subscription-id>` with the id of the identity subscription you created in the previous phase. |
    | `subscription_id_connectivity` | `<connectivity-subscription-id>` | Replace `<connectivity-subscription-id>` with the id of the connectivity subscription you created in the previous phase. |
    | `target_directory` | `<target-directory>` | This is the directory where the ALZ module code will be created. This defaults a directory called `local` in the root of the accelerator directory if not supplied. |
    | `create_bootstrap_resources_in_azure` | `true` | This determines whether the bootstrap will create the bootstrap resources in Azure. This defaults to `true`. |
    | `bootstrap_subscription_id` | `""` | Enter the id of the subscription in which you would like to deploy the bootstrap resources in Azure. If left blank, the subscription you are connected to via `az login` will be used. In most cases this is the management subscription, but you can specifiy a separate subscription if you prefer. |
    | `service_name` | `alz` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-<service_name>-mgmt-uksouth-001`. We recommend using `alz` for this. |
    | `environment_name` | `mgmt` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-alz-<environment_name>-uksouth-001`. We recommend using `mgmt` for this. |
    | `postfix_number` | `1` | This is used to build up the names of your Azure and Azure DevOps resources, for example `rg-alz-mgmt-uksouth-<postfix_number>`. We recommend using `1` for this. |

1. Now head over to your chosen starter module documentation to get the specific inputs for that module. Come back here when you are done.
    - [Terraform Basic Starter Module][wiki_starter_module_terraform_basic]: Management groups and policies.
    - [Terraform Hub Networking Starter Module][wiki_starter_module_terraform_hubnetworking]: Management groups, policies and hub networking.
    - [Terraform Complete Starter Module][wiki_starter_module_terraform_complete]: Management groups, policies, hub networking with fully custom configuration.
1. In your PowerShell Core (pwsh) terminal run the module:

    ```pwsh
    # Windows (adjust the paths to match your setup)
    Deploy-Accelerator -inputs "c:\accelerator\config\inputs.yaml" -output "c:\accelerator\output"
    ```

    ```pwsh
    # Linux/Mac (adjust the paths to match your setup)
    Deploy-Accelerator -inputs "~/accelerator/config/inputs.yaml" -output "~/accelerator/output"
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
[example_powershell_inputs_local_bicep_complete]:     examples/powershell-inputs/inputs-local-bicep-complete.yaml "Example - PowerShell Inputs - Local - Bicep - Complete"
[example_powershell_inputs_local_terraform_basic]:     examples/powershell-inputs/inputs-local-terraform-basic.yaml "Example - PowerShell Inputs - Local - Terraform - Basic"
[example_powershell_inputs_local_terraform_hubnetworking]:     examples/powershell-inputs/inputs-local-terraform-hubnetworking.yaml "Example - PowerShell Inputs - Local - Terraform - Hub Networking"
[example_powershell_inputs_local_terraform_complete]:     examples/powershell-inputs/inputs-local-terraform-complete.yaml "Example - PowerShell Inputs - Local - Terraform - Complete"
