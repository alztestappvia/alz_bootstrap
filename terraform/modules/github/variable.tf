
variable "environment" {
  type        = string
  description = "The environment for the subscriptions"
}

variable "variables" {
  type        = map(string)
  description = "The variables to set in the GitHub project"
}

variable "application_repo_mapping" {
  type = map(object({
    application_object_id = string
    client_id             = string
    tenant_id             = string
    github_org            = string
    repository_name       = string
    environment           = string
  }))
  description = "The mapping of applications to repositories"
}

