resource "azurecaf_name" "firewall_config" {
  name          = "firewall-policies"
  resource_type = "azurerm_resource_group"
  suffixes      = [lower(var.environment)]
  random_length = 4
}

# This uses azapi as the subscription id may not be known when the azurerm provider is initialised.
resource "azapi_resource" "firewall_config" {
  parent_id = module.platform_subscription["connectivity"].subscription_resource_id
  type      = "Microsoft.Resources/resourceGroups@2021-04-01"
  name      = azurecaf_name.firewall_config.result
  location  = var.primary_location
  tags      = var.tags
}

resource "azurerm_role_assignment" "firewall_config" {
  scope                = azapi_resource.firewall_config.id
  principal_id         = module.service_principal["id-alz-firewall-config"].rbac_id
  role_definition_name = "Contributor"
}
