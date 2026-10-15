# Auth0 settings (tenant, custom domain, API audience, SPA hosts, test user) live in ../../auth0.

# --- Azure providers ---

variable "azure_subscription_id" {
  description = "ID of the Azure subscription that holds the resource group and the storage account."
  type        = string
}

variable "azure_location" {
  description = "Azure region of the resource group and the storage account."
  type        = string
  default     = "australiaeast"
}

# --- Demo configuration ---

variable "name_prefix" {
  description = "Prefix for the names of created Azure resources (letters, digits and dashes)."
  type        = string
  default     = "auth0-wif-demo"
}

variable "additional_subjects" {
  description = "Auth0 user IDs (the `sub` claim, e.g. auth0|abc123) allowed to use the app registration, besides the Terraform test user. Each one gets its own federated credential (an Entra app allows 20)."
  type        = list(string)
  default     = []
}

variable "object_expiration_days" {
  description = "Days after which uploaded demo blobs under users/ are deleted by a lifecycle management rule."
  type        = number
  default     = 7
}
