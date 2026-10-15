# Auth0 values below are re-exported from ../../auth0 so gcp/scripts and gcp/spa read everything from this root.
output "auth0_domain" {
  description = "Auth0 tenant domain."
  value       = local.auth0.auth0_domain
}

output "auth0_issuer_domain" {
  description = "Domain clients must log in against: the verified custom domain, else the tenant domain. It determines the token issuer."
  value       = local.issuer_domain
}

output "auth0_issuer" {
  description = "OIDC issuer trusted by the workload identity provider."
  value       = local.issuer_url
}

output "api_audience" {
  description = "Audience to request when obtaining the access token."
  value       = local.auth0.gcp_api_audience
}

output "other_api_audience" {
  description = "Second API audience, for the audience negative test."
  value       = local.auth0.other_api_audience
}

output "spa_client_id" {
  description = "Auth0 SPA client ID (checked through the token's azp claim)."
  value       = local.auth0.gcp_spa_client_id
}

output "cli_client_id" {
  description = "Auth0 native client ID used by the gcp scripts (device flow)."
  value       = local.auth0.gcp_cli_client_id
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
  description = "All origins allowed for the SPA (Auth0 URLs and bucket CORS)."
  value       = local.spa_origins
}

output "gcp_project_id" {
  description = "Google Cloud project ID."
  value       = var.gcp_project_id
}

output "gcp_project_number" {
  description = "Google Cloud project number (appears in the pool and principal names)."
  value       = split("/", google_iam_workload_identity_pool.auth0.name)[1]
}

output "gcp_region" {
  description = "Location of the bucket."
  value       = var.gcp_region
}

output "workload_identity_provider" {
  description = "Audience of the Google STS token exchange: the full resource name of the workload identity provider."
  value       = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.auth0.name}"
}

output "principal_set" {
  description = "Principal granted roles/storage.objectUser on the bucket (every identity in the pool)."
  value       = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.auth0.name}/*"
}

output "bucket_name" {
  description = "Demo bucket. Objects are kept under users/<sub>/ by convention."
  value       = google_storage_bucket.demo.name
}

output "custom_domain_status" {
  description = "Auth0 status of the custom domain (null when none is configured). Absent from the Auth0 outputs while null, hence the try()."
  value       = try(local.auth0.custom_domain_status, null)
}
