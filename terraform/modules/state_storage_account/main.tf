resource "azurecaf_name" "rg" {
  name          = "${var.name}-state"
  resource_type = "azurerm_resource_group"
  suffixes      = [lower(var.environment)]
  random_length = 4
}

resource "azurerm_resource_group" "state" {
  name     = azurecaf_name.rg.result
  location = var.location
  tags     = var.tags
}

resource "azurecaf_name" "storage" {
  name          = "${var.name}state"
  resource_type = "azurerm_storage_account"
  suffixes      = [lower(var.environment)]
  random_length = 4
}

resource "azurerm_storage_account" "state" {
  #checkov:skip=CKV_AZURE_33:No queue storage required.
  #checkov:skip=CKV2_AZURE_21:Cannot do this until after bootstrap.
  #checkov:skip=CKV_AZURE_59:Attribute has been renamed.  Checkov is incorrect.
  name                            = azurecaf_name.storage.result
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  account_replication_type        = "GRS"
  public_network_access_enabled   = var.private_endpoint_subnet_id == null ? true : false
  shared_access_key_enabled       = true

  dynamic "network_rules" {
    for_each = var.private_endpoint_subnet_id == null ? [] : [1]
    content {
      default_action = "Deny"
    }
  }
  tags = var.tags
}

resource "azurerm_storage_container" "state" {
  #checkov:skip=CKV2_AZURE_21:Cannot do this until after bootstrap.
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

resource "azurerm_role_assignment" "state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = var.principal_id
}

resource "azurerm_role_assignment" "state_readers" {
  for_each             = var.reader_principal_ids
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value
}

resource "azurerm_private_endpoint" "state" {
  count               = var.bootstrap_mode == "true" ? 0 : 1
  name                = "pend-${azurerm_storage_account.state.name}"
  resource_group_name = azurerm_storage_account.state.resource_group_name
  location            = azurerm_resource_group.state.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = azurerm_storage_account.state.name
    private_connection_resource_id = azurerm_storage_account.state.id
    is_manual_connection           = false

    subresource_names = ["blob"]
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # DNS is configured via Azure Policy, so we don't want to fiddle with it
      private_dns_zone_group
    ]
  }
}
