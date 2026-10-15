# --- Auth0 provider (Terraform's own M2M client, supplied in terraform.auth.tfvars) ---

variable "auth0_domain" {
  description = "Auth0 tenant domain, e.g. my-tenant.us.auth0.com (no scheme)."
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

# --- Tenant-wide configuration ---

variable "auth0_custom_domain" {
  description = "Auth0-managed custom domain for the tenant, e.g. id.wif.abbaspour.net. Empty means no custom domain. Tokens are then issued with iss = https://<custom domain>/ once auth0_custom_domain_verified is true."
  type        = string
  default     = ""

  validation {
    condition     = !can(regex("^https?://", var.auth0_custom_domain)) && !endswith(var.auth0_custom_domain, "/")
    error_message = "auth0_custom_domain must be a bare hostname without scheme or trailing slash."
  }
}

variable "auth0_custom_domain_verified" {
  description = "Set to true only after the DNS record for the custom domain exists (see the custom_domain_dns_records output). Runs Auth0's verification and switches the issuer to the custom domain."
  type        = bool
  default     = false

  validation {
    condition     = !var.auth0_custom_domain_verified || var.auth0_custom_domain != ""
    error_message = "auth0_custom_domain_verified requires auth0_custom_domain to be set."
  }
}

variable "name_prefix" {
  description = "Prefix for the names of created Auth0 resources."
  type        = string
  default     = "auth0-wif-demo"
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

variable "other_api_audience" {
  description = "Identifier of a second Auth0 API, used only to test that its tokens are rejected by the cloud trust."
  type        = string
  default     = "https://other.wif"
}

# --- AWS demo ---

variable "aws_api_audience" {
  description = "Identifier (audience) of the Auth0 API whose access tokens are exchanged with AWS STS."
  type        = string
  default     = "https://aws.wif"
}

variable "aws_spa_domain" {
  description = "Hostname the deployed AWS SPA is served from (Cloudflare Worker custom domain), e.g. aws.wif.abbaspour.net. Must match the route in aws/spa/wrangler.jsonc. Empty for local-only use."
  type        = string
  default     = ""

  validation {
    condition     = !can(regex("^https?://", var.aws_spa_domain)) && !endswith(var.aws_spa_domain, "/")
    error_message = "aws_spa_domain must be a bare hostname without scheme or trailing slash."
  }
}

variable "aws_spa_origins" {
  description = "Local origins the AWS demo SPA is served from (aws_spa_domain is added to these). Used for Auth0 callback/logout/web-origin URLs and S3 CORS."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

# --- GCP demo ---

variable "gcp_api_audience" {
  description = "Identifier (audience) of the Auth0 API whose access tokens are exchanged with Google STS."
  type        = string
  default     = "https://gcp.wif"
}

variable "gcp_spa_domain" {
  description = "Hostname the deployed GCP SPA is served from (Cloudflare Worker custom domain), e.g. gcp.wif.abbaspour.net. Must match the route in gcp/spa/wrangler.jsonc. Empty for local-only use."
  type        = string
  default     = ""

  validation {
    condition     = !can(regex("^https?://", var.gcp_spa_domain)) && !endswith(var.gcp_spa_domain, "/")
    error_message = "gcp_spa_domain must be a bare hostname without scheme or trailing slash."
  }
}

variable "gcp_spa_origins" {
  description = "Local origins the GCP demo SPA is served from (gcp_spa_domain is added to these). Used for Auth0 callback/logout/web-origin URLs and bucket CORS."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

# --- Azure demo ---

variable "azure_api_audience" {
  description = "Identifier (audience) of the Auth0 API whose access tokens are exchanged with Microsoft Entra ID. A classic federated credential accepts exactly one audience; Microsoft recommends api://AzureADTokenExchange."
  type        = string
  default     = "api://AzureADTokenExchange"
}

variable "azure_spa_domain" {
  description = "Hostname the deployed Azure SPA is served from (Cloudflare Worker custom domain), e.g. azure.wif.abbaspour.net. Must match the route in azure/spa/wrangler.jsonc. Empty for local-only use."
  type        = string
  default     = ""

  validation {
    condition     = !can(regex("^https?://", var.azure_spa_domain)) && !endswith(var.azure_spa_domain, "/")
    error_message = "azure_spa_domain must be a bare hostname without scheme or trailing slash."
  }
}

variable "azure_spa_origins" {
  description = "Local origins the Azure demo SPA is served from (azure_spa_domain is added to these). Used for Auth0 callback/logout/web-origin URLs and storage CORS."
  type        = list(string)
  default     = ["http://localhost:5173"]
}
