terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7"
    }
  }
}

# Authenticates with Application Default Credentials: `gcloud auth application-default login`.
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
