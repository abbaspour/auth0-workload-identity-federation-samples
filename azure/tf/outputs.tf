# Auth0 values below are re-exported from ../../auth0 so azure/scripts and azure/spa read everything from this root.
output "auth0_domain" {
  description = "Auth0 tenant domain."
  value       = local.auth0.auth0_domain
}

output "auth0_issuer_domain" {
  description = "Domain clients must log in against: the verified custom domain, else the tenant domain. It determines the token issuer."
  value       = local.issuer_domain
}

output "auth0_issuer" {
  description = "OIDC issuer trusted by the federated credentials."
  value       = local.issuer_url
}

output "api_audience" {
  description = "Audience to request when obtaining the access token."
  value       = local.auth0.azure_api_audience
}

output "other_api_audience" {
  description = "Second API audience, for the audience negative test."
  value       = local.auth0.other_api_audience
}

output "spa_client_id" {
  description = "Auth0 SPA client ID."
  value       = local.auth0.azure_spa_client_id
}

output "cli_client_id" {
  description = "Auth0 native client ID used by the azure scripts (device flow)."
  value       = local.auth0.azure_cli_client_id
}

output "test_user_email" {
  description = "Auth0 test user."
  value       = local.auth0.test_user_email
}

output "db_connection_name" {
  description = "Auth0 database connection the app and test user use (sign-up disabled)."
  value       = local.auth0.db_connection_name
}

output "spa_origins" {
  description = "All origins allowed for the SPA (Auth0 URLs and storage CORS)."
  value       = local.spa_origins
}

output "custom_domain_status" {
  description = "Auth0 status of the custom domain (null when none is configured). Absent from the Auth0 outputs while null, hence the try()."
  value       = try(local.auth0.custom_domain_status, null)
}

output "azure_tenant_id" {
  description = "Microsoft Entra tenant ID (part of the token endpoint)."
  value       = data.azuread_client_config.current.tenant_id
}

output "azure_client_id" {
  description = "Application (client) ID of the app registration that trusts Auth0. It is the client_id of the token exchange."
  value       = azuread_application_registration.demo.client_id
}

output "token_endpoint" {
  description = "Entra token endpoint where the Auth0 access token is presented as a client assertion."
  value       = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/oauth2/v2.0/token"
}

output "storage_scope" {
  description = "Scope requested in the token exchange: Azure Storage."
  value       = "https://storage.azure.com/.default"
}

output "allowed_subjects" {
  description = "Auth0 user IDs (sub) that have a federated credential, i.e. may exchange a token."
  value       = sort(tolist(local.subjects))
}

output "storage_account_name" {
  description = "Storage account holding the demo container."
  value       = azurerm_storage_account.demo.name
}

output "container_name" {
  description = "Demo container. Blobs are kept under users/<sub>/ by convention."
  value       = azurerm_storage_container.demo.name
}

output "blob_endpoint" {
  description = "Blob service endpoint of the storage account."
  value       = azurerm_storage_account.demo.primary_blob_endpoint
}
