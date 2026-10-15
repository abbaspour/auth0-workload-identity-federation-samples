terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.9"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
  }
}

# Both providers authenticate with the Azure CLI session: `az login`.
provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id

  # azurerm 5 registers no resource providers by default, and a fresh subscription does not have Storage registered.
  resource_providers_to_register = ["Microsoft.Storage"]

  # The storage account disables shared keys, so Terraform uses Entra ID for data-plane calls too.
  storage_use_azuread = true
}

provider "azuread" {}
