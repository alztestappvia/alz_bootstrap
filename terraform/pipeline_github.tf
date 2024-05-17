# tflint-ignore: terraform_standard_module_structure
variable "github_token" {
  type        = string
  description = "A GitHub OAuth / Personal Access Token"
  default     = null
}

# tflint-ignore: terraform_standard_module_structure
variable "github_owner" {
  type        = string
  description = "The GitHub organization"
  default     = "alztestappvia"
}

locals {
  repositories = {
    alz_management = {
      name     = "alz_management"
      identity = "id-alz-management"
    }
    alz_connectivity = {
      name     = "alz_connectivity"
      identity = "id-alz-connectivity"
    }
    alz_identity = {
      name     = "alz_identity"
      identity = "id-alz-identity"
    }
    alz_core = {
      name     = "alz_core"
      identity = "id-alz-core"
    }
    alz_firewall_config = {
      name     = "alz_firewall_config"
      identity = "id-alz-firewall-config"
    }
    alz_landingzones_apps = {
      name     = "alz_landingzones_apps"
      identity = "id-alz-vendor"
    }
    alz_landingzones_platform = {
      name     = "alz_landingzones_platform"
      identity = "id-alz-vendor"
    }
    alz_landingzones_sandboxes = {
      name     = "alz_landingzones_sandboxes"
      identity = "id-alz-vendor"
    }
  }

  application_repo_mapping = {
    for k, v in local.repositories : k => {
      application_object_id = module.service_principal[v.identity].azuread_application.object_id
      client_id             = module.service_principal[v.identity].azuread_application.client_id
      tenant_id             = data.azurerm_client_config.current.tenant_id
      github_org            = var.github_owner
      repository_name       = v.name
      environment           = var.environment
    }
  }
}

module "github" {
  source = "./modules/github"

  environment              = var.environment
  variables                = local.output_variable_set
  application_repo_mapping = local.application_repo_mapping
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}
