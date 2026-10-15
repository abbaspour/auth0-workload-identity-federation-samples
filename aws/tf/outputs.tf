# Auth0 values below are re-exported from ../../auth0 so aws/scripts and aws/spa read everything from this root.
output "auth0_domain" {
  description = "Auth0 tenant domain."
  value       = local.auth0.auth0_domain
}

output "auth0_issuer_domain" {
  description = "Domain clients must log in against: the verified custom domain, else the tenant domain. It determines the token issuer."
  value       = local.issuer_domain
}

output "auth0_issuer" {
  description = "OIDC issuer trusted by the IAM OIDC provider."
  value       = local.issuer_url
}

output "api_audience" {
  description = "Audience to request when obtaining the access token."
  value       = local.auth0.aws_api_audience
}

output "other_api_audience" {
  description = "Second API audience, for the oaud negative test."
  value       = local.auth0.other_api_audience
}

output "spa_client_id" {
  description = "Auth0 SPA client ID (the value AWS matches as the token audience)."
  value       = local.auth0.aws_spa_client_id
}

output "cli_client_id" {
  description = "Auth0 native client ID used by the Phase 2 scripts (device flow)."
  value       = local.auth0.aws_cli_client_id
}

output "test_user_email" {
  description = "Auth0 test user."
  value       = local.auth0.test_user_email
}

output "oidc_provider_arn" {
  description = "IAM OIDC identity provider ARN."
  value       = aws_iam_openid_connect_provider.auth0.arn
}

output "role_arn" {
  description = "Role to pass to sts:AssumeRoleWithWebIdentity."
  value       = aws_iam_role.federated.arn
}

output "bucket_name" {
  description = "Demo S3 bucket. Users get access to users/<sub>/ only."
  value       = aws_s3_bucket.demo.bucket
}

output "aws_region" {
  description = "AWS region of the bucket."
  value       = var.aws_region
}

output "custom_domain_status" {
  description = "Auth0 status of the custom domain (null when none is configured). Absent from the Auth0 outputs while null, hence the try()."
  value       = try(local.auth0.custom_domain_status, null)
}

output "custom_domain_dns_records" {
  description = "DNS record(s) to create for the custom domain: type (name), host (domain) and target (record)."
  value       = try(local.auth0.custom_domain_dns_records, [])
}

output "db_connection_name" {
  description = "Auth0 database connection the app and test user use (sign-up disabled)."
  value       = local.auth0.db_connection_name
}

output "spa_origins" {
  description = "All origins allowed for the SPA (Auth0 URLs and S3 CORS)."
  value       = local.spa_origins
}
