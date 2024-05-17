locals {
  github_variables = flatten([for repo_key, repo_value in var.application_repo_mapping : [
    for k, v in var.variables : [
      {
        repository_name = repo_value.repository_name
        variable_name   = replace(k, "-", "_")
        variable_value  = v
      }
    ]
    ]
  ])
}

resource "github_actions_environment_variable" "state_variables" {
  count         = length(local.github_variables)
  repository    = local.github_variables[count.index].repository_name
  environment   = var.environment
  variable_name = local.github_variables[count.index].variable_name
  value         = local.github_variables[count.index].variable_value
}

resource "azuread_application_federated_identity_credential" "github" {
  for_each       = var.application_repo_mapping
  application_id = "/applications/${each.value.application_object_id}"
  display_name   = "github-${each.value.github_org}-${each.value.repository_name}-${each.value.environment}"
  description    = "Deployments for ${each.value.github_org}/${each.value.repository_name} in ${each.value.environment} environment"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${each.value.github_org}/${each.value.repository_name}:environment:${each.value.environment}"
}

resource "github_actions_environment_variable" "client_id" {
  for_each      = var.application_repo_mapping
  repository    = each.value.repository_name
  environment   = each.value.environment
  variable_name = "AZURE_CLIENT_ID"
  value         = each.value.client_id
}

resource "github_actions_environment_variable" "tenant_id" {
  for_each      = var.application_repo_mapping
  repository    = each.value.repository_name
  environment   = each.value.environment
  variable_name = "AZURE_TENANT_ID"
  value         = each.value.tenant_id
}
