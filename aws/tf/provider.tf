terraform {
  required_version = ">= 1.6"

  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = "~> 1.59"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_client_id
  client_secret = var.auth0_client_secret
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region

  default_tags {
    tags = {
      Project = "auth0-workload-identity-examples"
    }
  }
}
