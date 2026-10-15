# --- Tenant-wide ---

output "auth0_domain" {
  description = "Auth0 tenant domain."
  value       = var.auth0_domain
}

output "auth0_issuer_domain" {
  description = "Domain clients must log in against: the verified custom domain, else the tenant domain. It determines the token issuer."
  value       = local.issuer_domain
}

output "auth0_issuer" {
  description = "OIDC issuer the cloud providers trust."
  value       = local.issuer_url
}

output "test_user_email" {
  description = "Auth0 test user."
  value       = auth0_user.test.email
}

output "test_user_id" {
  description = "Auth0 user ID (the `sub` claim) of the test user. Azure federated credentials match it exactly."
  value       = auth0_user.test.user_id
}

output "db_connection_name" {
  description = "Auth0 database connection the apps and the test user use (sign-up disabled)."
  value       = auth0_connection.users.name
}

output "other_api_audience" {
  description = "Second API audience, for the audience negative test."
  value       = auth0_resource_server.other.identifier
}

output "custom_domain_status" {
  description = "Auth0 status of the custom domain (null when none is configured)."
  value       = one(auth0_custom_domain.main[*].status)
}

output "custom_domain_dns_records" {
  description = "DNS record(s) to create for the custom domain: type (name), host (domain) and target (record)."
  value       = try(auth0_custom_domain.main[0].verification[0].methods, [])
}

# --- AWS ---

output "aws_api_audience" {
  description = "Audience to request when obtaining the access token for AWS."
  value       = auth0_resource_server.aws_api.identifier
}

output "aws_spa_client_id" {
  description = "Auth0 SPA client ID of the AWS demo (the value AWS matches as the token audience)."
  value       = auth0_client.aws_spa.client_id
}

output "aws_cli_client_id" {
  description = "Auth0 native client ID used by the AWS scripts (device flow)."
  value       = auth0_client.aws_cli.client_id
}

output "aws_spa_origins" {
  description = "All origins allowed for the AWS SPA (Auth0 URLs and S3 CORS)."
  value       = local.aws_spa_origins
}

# --- GCP ---

output "gcp_api_audience" {
  description = "Audience to request when obtaining the access token for GCP."
  value       = auth0_resource_server.gcp_api.identifier
}

output "gcp_spa_client_id" {
  description = "Auth0 SPA client ID of the GCP demo."
  value       = auth0_client.gcp_spa.client_id
}

output "gcp_cli_client_id" {
  description = "Auth0 native client ID used by the GCP scripts (device flow)."
  value       = auth0_client.gcp_cli.client_id
}

output "gcp_spa_origins" {
  description = "All origins allowed for the GCP SPA (Auth0 URLs and bucket CORS)."
  value       = local.gcp_spa_origins
}

# --- Azure ---

output "azure_api_audience" {
  description = "Audience to request when obtaining the access token for Azure."
  value       = auth0_resource_server.azure_api.identifier
}

output "azure_spa_client_id" {
  description = "Auth0 SPA client ID of the Azure demo."
  value       = auth0_client.azure_spa.client_id
}

output "azure_cli_client_id" {
  description = "Auth0 native client ID used by the Azure scripts (device flow)."
  value       = auth0_client.azure_cli.client_id
}

output "azure_spa_origins" {
  description = "All origins allowed for the Azure SPA (Auth0 URLs and storage CORS)."
  value       = local.azure_spa_origins
}
