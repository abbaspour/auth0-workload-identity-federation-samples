data "azuread_client_config" "current" {}

locals {
  container_name = "demo"

  # Account names are global, 3-24 lowercase letters and digits: derive a stable suffix from the subscription.
  storage_account_name = "${substr(replace(lower(var.name_prefix), "/[^a-z0-9]/", ""), 0, 17)}${substr(sha1(var.azure_subscription_id), 0, 6)}"

  # A classic federated credential matches one exact `sub` (no wildcards), so every allowed user is listed here.
  subjects = toset(concat([local.auth0.test_user_id], var.additional_subjects))
}

# --- Identity: an app registration that trusts Auth0 tokens ---

resource "azuread_application_registration" "demo" {
  display_name     = var.name_prefix
  description      = "Auth0 workload identity federation demo."
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_service_principal" "demo" {
  client_id = azuread_application_registration.demo.client_id
}

# One credential per allowed user. Entra matches the token's issuer, subject and (single) audience against these
# exactly; it never looks at `azp`. A wrong subject is accepted here and only fails later, at the token exchange.
# (Flexible, claim-matching credentials would avoid the list, but Entra supports them only for GitHub, GitLab
# and Terraform Cloud issuers.)
resource "azuread_application_federated_identity_credential" "user" {
  for_each = local.subjects

  application_id = azuread_application_registration.demo.id
  display_name   = "user-${substr(sha1(each.value), 0, 12)}"
  description    = "Auth0 user ${each.value}"

  issuer    = local.issuer_url
  subject   = each.value
  audiences = [local.auth0.azure_api_audience]
}

# --- Storage ---

resource "azurerm_resource_group" "demo" {
  name     = "${var.name_prefix}-rg"
  location = var.azure_location
}

resource "azurerm_storage_account" "demo" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # Entra ID tokens are the only way in
  default_to_oauth_authentication = true

  # The SPA calls Blob Storage directly from the browser.
  blob_properties {
    cors_rule {
      allowed_origins    = local.spa_origins
      allowed_methods    = ["GET", "PUT", "HEAD", "OPTIONS"]
      allowed_headers    = ["authorization", "content-type", "x-ms-*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3000
    }
  }
}

resource "azurerm_storage_container" "demo" {
  name               = local.container_name
  storage_account_id = azurerm_storage_account.demo.id
}

# Demo hygiene: uploads are temporary.
resource "azurerm_storage_management_policy" "expire" {
  storage_account_id = azurerm_storage_account.demo.id

  rule {
    name    = "expire-uploads"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${local.container_name}/users/"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.object_expiration_days
      }
    }
  }
}

# The app's service principal gets blob data access on the container. Everyone who can exchange a token (every
# subject with a credential above) acts as this one principal, so, as on GCP, nothing restricts a user to their own
# users/<sub>/ prefix; see the README.
resource "azurerm_role_assignment" "blob_contributor" {
  scope                = azurerm_storage_container.demo.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.demo.object_id
  principal_type       = "ServicePrincipal"
}
