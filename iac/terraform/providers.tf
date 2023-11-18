terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}

  skip_provider_registration = "true"

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}
