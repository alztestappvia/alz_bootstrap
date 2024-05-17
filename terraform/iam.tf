module "service_principal" {
  for_each = local.service_principals
  # tflint-ignore: terraform_module_pinned_source
  source          = "git::https://github.com/alztestappvia/alz_tfmod_appreg?ref=main"
  name            = each.value.name
  directory_roles = lookup(each.value, "directory_roles", [])
  tags            = var.tags
  tenant_id       = data.azurerm_client_config.current.tenant_id
}
