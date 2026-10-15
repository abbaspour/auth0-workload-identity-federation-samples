# Auth0 settings (tenant, custom domain, API audience, SPA hosts, test user) live in ../../auth0.

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
  description = "Prefix for the names of created AWS resources."
  type        = string
  default     = "auth0-wif-demo"
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

variable "object_expiration_days" {
  description = "Days after which uploaded demo objects under users/ are deleted by an S3 lifecycle rule."
  type        = number
  default     = 7
}
