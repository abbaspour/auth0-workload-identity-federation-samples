# --- Auth0 provider (Terraform's own M2M client, supplied in terraform.auth.tfvars) ---

variable "auth0_domain" {
  description = "Auth0 tenant domain, e.g. my-tenant.us.auth0.com (no scheme). Also used as the OIDC issuer: https://<domain>/"
  type        = string

  validation {
    condition     = !can(regex("^https?://", var.auth0_domain)) && !endswith(var.auth0_domain, "/")
    error_message = "auth0_domain must be a bare hostname without scheme or trailing slash."
  }
}

variable "auth0_client_id" {
  description = "Client ID of the Auth0 M2M application Terraform uses to call the Management API."
  type        = string
}

variable "auth0_client_secret" {
  description = "Client secret of the Auth0 M2M application Terraform uses to call the Management API."
  type        = string
  sensitive   = true
}

# --- AWS provider ---

variable "aws_profile" {
  description = "AWS CLI profile name used by the Terraform AWS provider."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the S3 bucket and provider."
  type        = string
  default     = "us-east-1"
}

# --- Demo configuration ---

variable "name_prefix" {
  description = "Prefix for the names of created Auth0 and AWS resources."
  type        = string
  default     = "auth0-wif-demo"
}

variable "api_audience" {
  description = "Identifier (audience) of the Auth0 API whose access tokens are exchanged with AWS STS."
  type        = string
  default     = "https://aws.workload-identity.demo"
}

variable "spa_origins" {
  description = "Origins the demo SPA is served from. Used for Auth0 callback/logout/web-origin URLs and S3 CORS."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

variable "test_user_email" {
  description = "Email of the Auth0 test user created in the database connection."
  type        = string
}

variable "test_user_password" {
  description = "Password of the Auth0 test user."
  type        = string
  sensitive   = true
}

variable "db_connection_name" {
  description = "Existing Auth0 database connection the SPA is enabled on and the test user is created in."
  type        = string
  default     = "Username-Password-Authentication"
}

variable "role_session_duration" {
  description = "Maximum session duration (seconds) of the federated IAM role, 3600-43200."
  type        = number
  default     = 3600
}

variable "bucket_force_destroy" {
  description = "Allow terraform destroy to delete the S3 bucket even when it contains objects (demo convenience)."
  type        = bool
  default     = true
}
