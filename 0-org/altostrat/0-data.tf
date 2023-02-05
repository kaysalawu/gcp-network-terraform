
provider "google" {}
provider "google-beta" {}

provider "acme" {
  alias      = "staging"
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

provider "acme" {
  alias      = "production"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
  #version    = "= 1.5.0"
}

# projects

data "google_project" "hub" {
  project_id = var.project_id_hub
}

data "google_project" "spoke1" {
  project_id = var.project_id_spoke1
}

data "google_project" "spoke2" {
  project_id = var.project_id_spoke2
}

data "google_project" "spoke3" {
  project_id = var.project_id_spoke2
}

# locals

locals {
  prefix = "global-"
}
