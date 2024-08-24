
# auth

data "google_iam_policy" "noauth" {
  binding {
    role    = "roles/run.invoker"
    members = ["allUsers"]
  }
}

locals {
  spoke1_run_flasky_port        = 8080
  spoke1_run_flasky_gcr_host    = "gcr.io"
  spoke1_run_flasky_repo        = "${local.spoke1_run_flasky_gcr_host}/${var.project_id_spoke1}/flasky:v1"
  spoke1_run_flasky_repo_create = templatefile("../../templates/run/flasky/create.sh", local.spoke1_run_flasky_repo_vars)
  spoke1_run_flasky_repo_delete = templatefile("../../templates/run/flasky/delete.sh", local.spoke1_run_flasky_repo_vars)
  spoke1_run_flasky_repo_vars = {
    PROJECT        = var.project_id_spoke1
    GCR_HOST       = local.spoke1_run_flasky_gcr_host
    IMAGE_REPO     = local.spoke1_run_flasky_repo
    CONTAINER_PORT = local.spoke1_run_flasky_port
    DOCKERFILE_DIR = "../../templates/run/flasky"
  }
}

resource "null_resource" "spoke1_run_flasky_repo" {
  triggers = {
    create = local.spoke1_run_flasky_repo_create
    delete = local.spoke1_run_flasky_repo_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# run instance

resource "google_cloud_run_service" "spoke1_run_flasky" {
  project  = var.project_id_spoke1
  name     = "${local.spoke1_prefix}run-flasky"
  location = local.spoke1_eu_region
  template {
    spec {
      containers {
        image = local.spoke1_run_flasky_repo
        ports {
          name           = "http1"
          container_port = local.spoke1_run_flasky_port
        }
      }
    }
  }
  metadata {
    annotations = {
      "run.googleapis.com/client-name" = "terraform"
    }
  }
  depends_on = [null_resource.spoke1_run_flasky_repo]
}

resource "google_cloud_run_service_iam_policy" "spoke1_run_flasky" {
  project     = var.project_id_spoke1
  location    = local.spoke1_eu_region
  service     = google_cloud_run_service.spoke1_run_flasky.name
  policy_data = data.google_iam_policy.noauth.policy_data
}
