<!-- markdownlint-disable first-line-heading first-line-h1 -->
Welcome to the Azure landing zones Terraform accelerator!

The Azure landing zones [Terraform][alz_tf_module] and [Bicep][alz_bc_module] provide an opinionated approach for deploying and managing the core platform capabilities of [Azure landing zones architecture][alz_architecture] using Terraform or Bicep.

This accelerator provides an opinionated approach for configuring and securing that module in a continuous delivery environment. It has end to end automation for bootstrapping the modules.

## Supported Version Control Systems (VCS)

The accelerator supports both Azure DevOps and GitHub. We are only able to support the hosted versions of these services.

If you are using self-hosted versions of these services or another VCS, you can still use the accelerator to produce the landing zone code by using the `-c "local"` flag option, but you will need to configure the VCS manually or with your own automation.

## Accelerator features

The accelerator bootstraps a continuous delivery environment for you. It supports both the Azure DevOps and GitHub version control system (VCS). It uses the [ALZ](https://www.powershellgallery.com/packages/ALZ) PowerShell module to gather required user input and apply a Terraform module to configure the bootstrap environment.

> NOTE: For Bicep users, the accelerator uses Terraform to bootstrap the environment only. Bicep is used to deploy and update the Azure landing zone.

The accelerator follows a 3 phase approach:

1. Pre-requisites: Instructions to configure credentials and subscriptions.
2. Bootstrap: Run the PowerShell module to generate the continuous delivery environment.
3. Run: Update the module (if needed) to suit the needs of your organisation and deploy via continuous delivery.

![Azure landing zone accelerator process][alz_accelerator_overview]

The components of the environment are similar, but differ depending on your choice of VCS:

![Components][components]

### GitHub

- Azure:
  - Resource Group for State (Terraform only)
  - Storage Account and Container for State (Terraform only)
  - Resource Group for Identity
  - User Assigned Managed Identities (UAMI) with Federated Credentials for Plan and Apply
  - Permissions for the UAMI on state storage container, subscriptions and management groups
  - [Optional] Container Registry for GitHub Runner image
  - [Optional] Container Instances hosting GitHub Runners
  - [Optional] Virtual network, subnets, private DNS zone and private endpoint.

- GitHub
  - Repository for the Module
  - Repository for the Action Templates
  - Starter Terraform module with tfvars
  - Branch policy
  - Action for Continuous Integration
  - Action for Continuous Delivery
  - Environment for Plan
  - Environment for Apply
  - Action Variables for Backend and Plan / Apply
  - Team and Members for Apply Approval
  - Customised OIDC Token Subject for governed Actions
  - [Optional] Runner Group

### Azure DevOps

- Azure:
  - Resource Group for State (Terraform only)
  - Storage Account and Container for State (Terraform only)
  - Resource Group for Identity
  - User Assigned Managed Identities (UAMI) with Federated Credentials for Plan and Apply
  - Permissions for the UAMI on state storage container, subscriptions and management groups
  - [Optional] Container Registry for Azure DevOps Agent image
  - [Optional] Container Instances hosting Azure DevOps Agents
  - [Optional] Virtual network, subnets, private DNS zone and private endpoint.

- Azure DevOps
  - Project (can be supplied or created)
  - Repository for the Module
  - Repository for the Pipeline Templates
  - Starter Terraform module with tfvars
  - Branch policy
  - Pipeline for Continuous Integration
  - Pipeline for Continuous Delivery
  - Environment for Plan
  - Environment for Apply
  - Variable Group for Backend
  - Service Connections with Workload identity federation for Plan and Apply
  - Service Connection Approvals, Template Validation and Concurrency Control
  - Group and Members for Apply Approval
  - [Optional] Agent Pool

### Local File System

This outputs the ALZ module files to the file system, so you can apply them manually or with your own VCS / automation.

- Azure:
  - Resource Group for State (Terraform only)
  - Storage Account and Container for State (Terraform only)
  - Resource Group for Identity
  - User Assigned Managed Identities (UAMI) for Plan and Apply
  - Permissions for the UAMI on state storage container, subscriptions and management groups

- Local File System
  - Starter module with variables

## Next steps

Check out the [User Guide](User-Guide).

## Azure landing zones

The following diagram and links detail the Azure landing zone, but you can learn a lot more about Azure landing zones [here](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/).

![Azure landing zone conceptual architecture][alz_tf_overview]

 [//]: # (*****************************)
 [//]: # (INSERT IMAGE REFERENCES BELOW)
 [//]: # (*****************************)

[alz_accelerator_overview]: media/alz-terraform-acclerator.png "A process flow showing the areas covered by the Azure landing zones Terraform accelerator."
[components]: media/components.png "The components deployed by the accelerator."

[alz_tf_overview]: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/enterprise-scale/media/ns-arch-cust-expanded.svg "A conceptual architecture diagram highlighting the design areas covered by the Azure landing zones Terraform module."

 [//]: # (************************)
 [//]: # (INSERT LINK LABELS BELOW)
 [//]: # (************************)

[alz_tf_module]:  https://registry.terraform.io/modules/Azure/caf-enterprise-scale/azurerm/latest "Terraform: Azure landing zones module"
[alz_bc_module]:  https://github.com/Azure/ALZ-Bicep "Bicep: Azure landing zones module"
[alz_architecture]: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone#azure-landing-zone-conceptual-architecture
