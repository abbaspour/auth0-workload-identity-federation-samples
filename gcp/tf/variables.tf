# Auth0 settings (tenant, custom domain, API audience, SPA hosts, test user) live in ../../auth0.

# --- Google provider ---

variable "gcp_project_id" {
  description = "ID of the Google Cloud project that holds the workload identity pool and the bucket."
  type        = string
}

variable "gcp_region" {
  description = "Location of the Cloud Storage bucket and default region of the provider."
  type        = string
  default     = "us-central1"
}

# --- Demo configuration ---

variable "name_prefix" {
  description = "Prefix for the names of created Google Cloud resources (pool IDs allow 4-32 lowercase letters, digits and dashes)."
  type        = string
  default     = "auth0-wif-demo"
}

variable "bucket_force_destroy" {
  description = "Allow terraform destroy to delete the bucket even when it contains objects (demo convenience)."
  type        = bool
  default     = true
}

variable "object_expiration_days" {
  description = "Days after which uploaded demo objects under users/ are deleted by a bucket lifecycle rule."
  type        = number
  default     = 7
}
