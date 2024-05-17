variable "primary_location" {
  type        = string
  description = "The primary location for the subscriptions"
  default     = "uksouth"
}

variable "environment" {
  type        = string
  description = "The environment for the subscriptions"
}

variable "billing_scope" {
  type        = string
  description = "The billing scope for the subscriptions"
}

variable "existing_connectivity_subscription_id" {
  type        = string
  description = "The subscription ID for the connectivity subscription"
  default     = ""
}

variable "existing_management_subscription_id" {
  type        = string
  description = "The subscription ID for the management subscription"
  default     = ""
}

variable "existing_identity_subscription_id" {
  type        = string
  description = "The subscription ID for the identity subscription"
  default     = ""
}

variable "bootstrap_mode" {
  type        = string
  description = "Set to true to indicate that the bootstrap is in progress. This will cause storage accounts to be created without private endpoints."
}

variable "tags" {
  type        = map(string)
  description = "Set tags to apply to the resources"
  default = {
    WorkloadName        = "ALZ.Bootstrap"
    DataClassification  = "General"
    BusinessCriticality = "Mission-critical"
    BusinessUnit        = "Platform Operations"
    OperationsTeam      = "Platform Operations"
  }
}

variable "use_oidc" {
  type        = bool
  description = "Set to true to use OIDC for authentication"
  default     = false
}

variable "root_id" {
  type        = string
  description = "The ID of the root management group"
  default     = "alz"
}
