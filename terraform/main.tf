module "platform_subscription" {
  for_each = local.subscriptions
  source   = "Azure/lz-vending/azurerm"
  version  = "v3.4.1"

  location = var.primary_location

  subscription_id            = each.value.subscription_id
  subscription_alias_enabled = coalesce(each.value.subscription_id, "unknown") == "unknown" ? true : false
  subscription_billing_scope = var.billing_scope
  subscription_display_name  = each.value.name
  subscription_alias_name    = each.value.name
  subscription_workload      = "Production"

  network_watcher_resource_group_enabled           = true
  subscription_register_resource_providers_enabled = true

  subscription_management_group_association_enabled = false
  virtual_network_enabled                           = false
  role_assignment_enabled                           = true
  role_assignments = merge({
    owner = {
      principal_id   = module.service_principal[each.value.owner_service_principal_key].rbac_id
      definition     = "Owner"
      relative_scope = ""
    }
  }, each.value.additional_role_assignments)

  disable_telemetry = true
  subscription_tags = var.tags
}
