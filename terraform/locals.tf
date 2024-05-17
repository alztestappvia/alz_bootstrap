locals {
  bootstrap_mode = lower(var.bootstrap_mode)
  service_principals = {
    "id-alz-core" = {
      name              = "id-${var.root_id}-core"
      subscription_keys = ["management"]
      short_name        = "core"
      state_readers     = ["id-alz-vendor"]
      directory_roles   = ["Groups Administrator", "Privileged Role Administrator"]
    }
    "id-alz-connectivity" = {
      name              = "id-${var.root_id}-connectivity"
      subscription_keys = ["connectivity"]
      short_name        = "connect"
      state_readers     = ["id-alz-core"]
      directory_roles   = ["Directory Readers", "Groups Administrator"]
    }
    "id-alz-management" = {
      name              = "id-${var.root_id}-management"
      subscription_keys = ["management"]
      short_name        = "mgmt"
      state_readers     = ["id-alz-core", "id-alz-connectivity"]
    }
    "id-alz-firewall-config" = {
      name              = "id-${var.root_id}-firewall-config"
      subscription_keys = ["connectivity"]
      short_name        = "fwconfig"
      state_readers     = ["id-alz-connectivity"]
    }
    "id-alz-identity" = {
      name              = "id-${var.root_id}-identity"
      subscription_keys = ["identity"]
      short_name        = "identity"
      state_readers     = ["id-alz-core"]
    }
    "id-alz-vendor" = {
      name              = "id-${var.root_id}-vendor"
      subscription_keys = ["management"]
      short_name        = "vendor"
      state_readers     = []
      directory_roles   = ["Groups Administrator", "Privileged Role Administrator", "Application Administrator"]
    }
  }

  subscriptions = {
    connectivity = {
      name                        = "alz-connectivity"
      owner_service_principal_key = "id-alz-connectivity"
      subscription_id             = var.existing_connectivity_subscription_id
      additional_role_assignments = {
        firewall_reader = {
          principal_id   = module.service_principal["id-alz-firewall-config"].rbac_id
          definition     = "Reader"
          relative_scope = ""
        },
        vendor_reader = {
          principal_id   = module.service_principal["id-alz-vendor"].rbac_id
          definition     = "Reader"
          relative_scope = ""
        }
        bootstrap_reader = {
          principal_id   = data.azurerm_client_config.current.object_id
          definition     = "Reader"
          relative_scope = ""
        }
      }
    }
    management = {
      name                        = "alz-management"
      owner_service_principal_key = "id-alz-management"
      subscription_id             = var.existing_management_subscription_id
      additional_role_assignments = {
        core_reader = {
          principal_id   = module.service_principal["id-alz-core"].rbac_id
          definition     = "Reader"
          relative_scope = ""
        },
        vendor_contributor = {
          principal_id   = module.service_principal["id-alz-vendor"].rbac_id
          definition     = "Contributor"
          relative_scope = ""
        }
      }
    }
    identity = {
      name                        = "alz-identity"
      owner_service_principal_key = "id-alz-identity"
      subscription_id             = var.existing_identity_subscription_id
      additional_role_assignments = {}
    }
  }

  output_variable_set = merge(
    {
      "subscription-state" = data.azurerm_client_config.current.subscription_id
      "rg-firewall-config" = azapi_resource.firewall_config.name
    },
    { for key, value in module.platform_subscription : "subscription-${key}" => value.subscription_id },
    { for key, value in module.state_storage : key => value.storage_account_name }
  )
}
