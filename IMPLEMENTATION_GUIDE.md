# GitHub Actions Repository Access Level Implementation Guide

## PowerShell Module Changes (This Repository) - COMPLETED

The PowerShell module now supports the `github_actions_repository_access_level` parameter:

1. **Parameter Support**: Added parameter handling in the configuration system
2. **Example Configuration**: Updated `inputs-github-terraform-complete-multi-region.yaml` 
3. **Tests**: Added comprehensive unit and integration tests
4. **Documentation**: Added inline documentation explaining the parameter

## Bootstrap Module Changes Required (Separate Repository)

To complete the fix, the bootstrap modules in the `accelerator-bootstrap-modules` repository need to:

### 1. Add Terraform Variable

Add this variable to the GitHub bootstrap module's `variables.tf`:

```hcl
variable "github_actions_repository_access_level" {
  description = "GitHub Actions repository access level for private repositories | github_actions_access_level"
  type        = string
  default     = "organization"
  
  validation {
    condition = contains(["none", "user", "organization", "enterprise"], var.github_actions_repository_access_level)
    error_message = "The github_actions_repository_access_level must be one of: none, user, organization, enterprise."
  }
}
```

### 2. Add Terraform Resource

Add this resource to configure the repository access level:

```hcl
resource "github_actions_repository_access_level" "main" {
  access_level = var.github_actions_repository_access_level
  repository   = github_repository.main.name
}

# If using separate template repository
resource "github_actions_repository_access_level" "template" {
  count        = var.use_separate_repository_for_templates ? 1 : 0
  access_level = var.github_actions_repository_access_level
  repository   = github_repository.template[0].name
}
```

### 3. Provider Requirements

Ensure the GitHub provider version supports this resource (available since v5.18.0):

```hcl
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 5.18.0"
    }
  }
}
```

## How This Resolves the Issue

1. **Root Cause**: GitHub Actions workflows can't access reusable workflows from private repositories in the same organization by default
2. **Solution**: The `github_actions_repository_access_level` resource configures the repository to allow access from other repositories in the organization
3. **Flow**: 
   - User sets `github_actions_repository_access_level: "organization"` in their configuration
   - PowerShell module passes this to the bootstrap Terraform module
   - Terraform creates the `github_actions_repository_access_level` resource
   - GitHub repository now allows organization-wide access for Actions workflows

## Testing the Complete Solution

After implementing the bootstrap module changes:

1. Run the accelerator with a GitHub configuration that includes `github_actions_repository_access_level: "organization"`
2. Verify the repository settings in GitHub show the correct Actions access level
3. Test that workflows can successfully call reusable workflows from the templates repository