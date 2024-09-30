<!-- markdownlint-disable first-line-h1 -->
![Azure logo](media/Logo-Small.png)

## Azure landing zones accelerators

- [Home][wiki_home]
- [User guide][wiki_user_guide]
  - [Getting started][wiki_getting_started]
  - [Quick Start][wiki_quick_start]
    - [Phase 1 - Pre-requisites][wiki_quick_start_phase_1]
      - [Service Principal][wiki_quick_start_phase_1_service_principal]
    - [Phase 2 - Bootstrap][wiki_quick_start_phase_2]
      - [Azure DevOps][wiki_quick_start_phase_2_azure_devops]
      - [GitHub][wiki_quick_start_phase_2_github]
      - [Local][wiki_quick_start_phase_2_local]
    - [Phase 3 - Run][wiki_quick_start_phase_3]
  - [Starter Modules][wiki_starter_modules]
    - [Bicep - Complete][wiki_starter_module_bicep_complete]
    - [Terraform - Basic][wiki_starter_module_terraform_basic]
    - [Terraform - Hub Networking][wiki_starter_module_terraform_hubnetworking]
    - [Terraform - Complete][wiki_starter_module_terraform_complete]
      - [Configuration YAML Schema][wiki_yaml_schema_reference]
      - [Example Hub and Spoke config][example_starter_module_complete_config_hub_spoke]
      - [Example Virtual WAN config][example_starter_module_complete_config_vwan]
    - [Terraform - Complete Multi Region][wiki_starter_module_terraform_complete_multi_region]
      - [Example Multi Region Hub and Spoke config][example_starter_module_complete_config_hub_spoke_multi_region]
      - [Example Multi Region Virtual WAN config][example_starter_module_complete_config_vwan_multi_region]
  - Input Files
    - [Azure DevOps Bicep Complete][example_powershell_inputs_azure_devops_bicep_complete]
    - [Azure DevOps Terraform Basic][example_powershell_inputs_azure_devops_terraform_basic]
    - [Azure DevOps Terraform Hub Networking][example_powershell_inputs_azure_devops_terraform_hubnetworking]
    - [Azure DevOps Terraform Complete][example_powershell_inputs_azure_devops_terraform_complete]
    - [Azure DevOps Terraform Complete Multi Region][example_powershell_inputs_azure_devops_terraform_complete_multi_region]
    - [GitHub Bicep Complete][example_powershell_inputs_github_bicep_complete]
    - [GitHub Terraform Basic][example_powershell_inputs_github_terraform_basic]
    - [GitHub Terraform Hub Networking][example_powershell_inputs_github_terraform_hubnetworking]
    - [GitHub Terraform Complete][example_powershell_inputs_github_terraform_complete]
    - [GitHub Terraform Complete Multi Region][example_powershell_inputs_github_terraform_complete_multi_region]
    - [Local Bicep Complete][example_powershell_inputs_local_bicep_complete]
    - [Local Terraform Basic][example_powershell_inputs_local_terraform_basic]
    - [Local Terraform Hub Networking][example_powershell_inputs_local_terraform_hubnetworking]
    - [Local Terraform Complete][example_powershell_inputs_local_terraform_complete]
    - [Local Terraform Complete Multi Region][example_powershell_inputs_local_terraform_complete_multi_region]
- [Frequently Asked Questions][wiki_frequently_asked_questions]
- [Upgrade Guide][wiki_upgrade_guide]
- [Advanced Scenarios][wiki_advanced_scenarios]
- [Troubleshooting][wiki_troubleshooting]
- [Contributing][wiki_contributing]
  - [Raising an issue][wiki_raising_an_issue]
  - [Feature requests][wiki_feature_requests]
  - [Contributing to code][wiki_contributing_to_code]
  - [Contributing to documentation][wiki_contributing_to_documentation]

[//]: # "************************"
[//]: # "INSERT LINK LABELS BELOW"
[//]: # "************************"

[wiki_home]:                                                         Home "Wiki - Home"
[wiki_user_guide]:                                                   User-Guide "Wiki - User guide"
[wiki_getting_started]:                                              %5BUser-Guide%5D-Getting-Started "Wiki - Getting started"
[wiki_quick_start]:                                                  %5BUser-Guide%5D-Quick-Start "Wiki - Quick start"
[wiki_quick_start_phase_1]:                                          %5BUser-Guide%5D-Quick-Start-Phase-1 "Wiki - Quick Start - Phase 1"
[wiki_quick_start_phase_1_service_principal]:                        %5BUser-Guide%5D-Quick-Start-Phase-1-Service-Principal "Wiki - Quick Start - Phase 1 - Service Principal"
[wiki_quick_start_phase_2]:                                          %5BUser-Guide%5D-Quick-Start-Phase-2 "Wiki - Quick Start - Phase 2"
[wiki_quick_start_phase_2_azure_devops]:                             %5BUser-Guide%5D-Quick-Start-Phase-2-Azure-DevOps "Wiki - Quick Start - Phase 2 - Azure DevOps"
[wiki_quick_start_phase_2_github]:                                   %5BUser-Guide%5D-Quick-Start-Phase-2-GitHub "Wiki - Quick Start - Phase 2 - GitHub"
[wiki_quick_start_phase_2_local]:                                    %5BUser-Guide%5D-Quick-Start-Phase-2-Local "Wiki - Quick Start - Phase 2 - Local"
[wiki_quick_start_phase_3]:                                          %5BUser-Guide%5D-Quick-Start-Phase-3 "Wiki - Quick Start - Phase 3"
[wiki_starter_modules]:                                              %5BUser-Guide%5D-Starter-Modules "Wiki - Starter Modules"
[wiki_starter_module_bicep_complete]:                                %5BUser-Guide%5D-Starter-Module-Bicep-Complete "Wiki - Starter Modules - Bicep Complete"
[wiki_starter_module_terraform_basic]:                               %5BUser-Guide%5D-Starter-Module-Terraform-Basic "Wiki - Starter Modules - Terraform Basic"
[wiki_starter_module_terraform_hubnetworking]:                       %5BUser-Guide%5D-Starter-Module-Terraform-HubNetworking "Wiki - Start Modules - Terraform Hub Networking"
[wiki_starter_module_terraform_complete]:                            %5BUser-Guide%5D-Starter-Module-Terraform-Complete "Wiki - Starter Modules - Terraform Complete"
[wiki_starter_module_terraform_complete_multi_region]:               %5BUser-Guide%5D-Starter-Module-Terraform-Complete-Multi-Region "Wiki - Starter Modules - Terraform Complete Multi Region"
[wiki_yaml_schema_reference]:                                        %5BUser-Guide%5D-YAML-Schema-Reference "Wiki - YAML Schema Reference"
[wiki_frequently_asked_questions]:                                   Frequently-Asked-Questions "Wiki - Frequently Asked Questions"
[wiki_troubleshooting]:                                              Troubleshooting "Wiki - Troubleshooting"
[wiki_contributing]:                                                 Contributing "Wiki - Contributing"
[wiki_raising_an_issue]:                                             Raising-an-Issue "Wiki - Raising an issue"
[wiki_feature_requests]:                                             Feature-Requests "Wiki - Feature requests"
[wiki_contributing_to_code]:                                         Contributing-to-Code "Wiki - Contributing to code"
[wiki_contributing_to_documentation]:                                Contributing-to-Documentation "Wiki - Contributing to documentation"
[wiki_upgrade_guide]:                                              Upgrade-Guide "Wiki - Upgrade Guide"
[wiki_advanced_scenarios]:                                           %5BUser-Guide%5D-Advanced-Scenarios "Wiki - Advanced Scenarios"
[example_powershell_inputs_azure_devops_bicep_complete]:     examples/powershell-inputs/inputs-azure-devops-bicep-complete.yaml "Example - PowerShell Inputs - Azure DevOps - Bicep - Complete"
[example_powershell_inputs_github_bicep_complete]:     examples/powershell-inputs/inputs-github-bicep-complete.yaml "Example - PowerShell Inputs - GitHub - Bicep - Complete"
[example_powershell_inputs_local_bicep_complete]:     examples/powershell-inputs/inputs-local-bicep-complete.yaml "Example - PowerShell Inputs - Local - Bicep - Complete"
[example_powershell_inputs_azure_devops_terraform_basic]:     examples/powershell-inputs/inputs-azure-devops-terraform-basic.yaml "Example - PowerShell Inputs - Azure DevOps - Terraform - Basic"
[example_powershell_inputs_github_terraform_basic]:     examples/powershell-inputs/inputs-github-terraform-basic.yaml "Example - PowerShell Inputs - GitHub - Terraform - Basic"
[example_powershell_inputs_local_terraform_basic]:     examples/powershell-inputs/inputs-local-terraform-basic.yaml "Example - PowerShell Inputs - Local - Terraform - Basic"
[example_powershell_inputs_azure_devops_terraform_hubnetworking]:     examples/powershell-inputs/inputs-azure-devops-terraform-hubnetworking.yaml "Example - PowerShell Inputs - Azure DevOps - Terraform - Hub Networking"
[example_powershell_inputs_github_terraform_hubnetworking]:     examples/powershell-inputs/inputs-github-terraform-hubnetworking.yaml "Example - PowerShell Inputs - GitHub - Terraform - Hub Networking"
[example_powershell_inputs_local_terraform_hubnetworking]:     examples/powershell-inputs/inputs-local-terraform-hubnetworking.yaml "Example - PowerShell Inputs - Local - Terraform - Hub Networking"
[example_powershell_inputs_azure_devops_terraform_complete]:     examples/powershell-inputs/inputs-azure-devops-terraform-complete.yaml "Example - PowerShell Inputs - Azure DevOps - Terraform - Complete"
[example_powershell_inputs_github_terraform_complete]:     examples/powershell-inputs/inputs-github-terraform-complete.yaml "Example - PowerShell Inputs - GitHub - Terraform - Complete"
[example_powershell_inputs_local_terraform_complete]:     examples/powershell-inputs/inputs-local-terraform-complete.yaml "Example - PowerShell Inputs - Local - Terraform - Complete"
[example_powershell_inputs_azure_devops_terraform_complete_multi_region]:     examples/powershell-inputs/inputs-azure-devops-terraform-complete-multi-region.yaml "Example - PowerShell Inputs - Azure DevOps - Terraform - Complete Multi Region"
[example_powershell_inputs_github_terraform_complete_multi_region]:     examples/powershell-inputs/inputs-github-terraform-complete-multi-region.yaml "Example - PowerShell Inputs - GitHub - Terraform - Complete Multi Region"
[example_powershell_inputs_local_terraform_complete_multi_region]:     examples/powershell-inputs/inputs-local-terraform-complete-multi-region.yaml "Example - PowerShell Inputs - Local - Terraform - Complete Multi Region"
[example_starter_module_complete_config_hub_spoke]: examples/starter-module-config/complete/config-hub-spoke.yaml "Example - Starter Module Config - Complete - Hub and Spoke"
[example_starter_module_complete_config_vwan]: examples/starter-module-config/complete/config-vwan.yaml "Example - Starter Module Config - Complete - Virtual WAN"
[example_starter_module_complete_config_hub_spoke_multi_region]: examples/starter-module-config/complete-multi-region/config-hub-and-spoke-vnet.yaml "Example - Starter Module Config - Complete - Hub and Spoke VNet Multi Region"
[example_starter_module_complete_config_vwan_multi_region]: examples/starter-module-config/complete-multi-region/config-virtual-wan.yaml "Example - Starter Module Config - Complete - Virtual WAN Multi Region"
