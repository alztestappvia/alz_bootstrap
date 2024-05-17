module "state_storage" {
  for_each = module.service_principal
  source   = "./modules/state_storage_account"

  name                       = local.service_principals[each.key].short_name
  location                   = var.primary_location
  principal_id               = each.value.rbac_id
  environment                = lower(var.environment)
  private_endpoint_subnet_id = local.bootstrap_mode == "true" ? null : "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/rg-state-networking/providers/Microsoft.Network/virtualNetworks/vnet-state/subnets/state-subnet"
  reader_principal_ids = {
    for principal_key in local.service_principals[each.key].state_readers : principal_key => module.service_principal[principal_key].rbac_id
  }
  tags           = var.tags
  bootstrap_mode = local.bootstrap_mode
}
