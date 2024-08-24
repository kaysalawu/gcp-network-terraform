
# # artifacts registry

# resource "google_artifact_registry_repository" "eu_repo" {
#   project       = var.project
#   location      = local.hub_eu_region
#   repository_id = "${local.prefix}-eu-repo"
#   format        = "DOCKER"
# }

# resource "google_artifact_registry_repository" "us_repo" {
#   project       = var.project_id_hub
#   location      = local.hub_us_region
#   repository_id = "${local.prefix}-us-repo"
#   format        = "DOCKER"
# }
