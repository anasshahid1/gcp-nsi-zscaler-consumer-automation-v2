terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.27.0, < 8.0.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.27.0, < 8.0.0"
    }
  }
}

provider "google" {
  project                     = var.project_id
  region                      = var.region
  billing_project             = var.billing_project_id
  user_project_override       = true
  # impersonate_service_account = var.impersonate_service_account
}

provider "google-beta" {
  project                     = var.project_id
  region                      = var.region
  billing_project             = var.billing_project_id
  user_project_override       = true
  # impersonate_service_account = var.impersonate_service_account
}
