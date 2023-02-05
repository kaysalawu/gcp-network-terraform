terraform {
  required_providers {
    acme = {
      source = "terraform-providers/acme"
    }
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
  }
  required_version = ">= 0.13"
}
