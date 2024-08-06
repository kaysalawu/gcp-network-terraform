
# common
#---------------------------------

locals {
  vm_startup = templatefile("../../scripts/startup/gce.sh", {
    ENABLE_PROBES = true
    SCRIPTS = {
      targets_app   = local.targets_app
      targets_ping  = local.targets_ping
      targets_pga   = local.targets_pga
      targets_psc   = local.targets_psc
      targets_probe = concat(local.targets_app, local.targets_pga)
      targets_bucket = {
        ("hub") = module.hub_eu_storage_bucket.name
      }
      targets_ai_project = [{ project = var.project_id_hub, region = local.hub_eu_region }, ]
    }
    WEB_SERVER = {
      port                  = local.svc_web.port
      health_check_path     = local.uhc_config.request_path
      health_check_response = local.uhc_config.response
    }
  })
  td_client_startup = templatefile("../../scripts/startup/client.sh", {
    TD_PROJECT_NUMBER = data.google_project.hub_project_number.number
    TD_NETWORK_NAME   = "${local.hub_prefix}vpc"
    TARGETS_GRPC      = local.targets_grpc
    TARGETS_ENVOY     = local.targets_td
  })
  targets_psc               = []
  targets_td                = []
  targets_grpc              = ["${local.hub_td_grpc_cloud_svc}.${local.hub_td_domain}", ]
  sql_access_via_local_host = []
  sql_access_via_proxy      = []
}

# on-premises
#---------------------------------

# unbound config

locals {
  onprem_local_records = [
    { name = ("${local.site1_app1_dns}.${local.site1_domain}.${local.onprem_domain}"), record = local.site1_app1_addr },
    { name = ("${local.site1_vertex_dns}.${local.site1_domain}.${local.onprem_domain}"), record = local.site1_vertex_addr },
    { name = ("${local.site2_app1_dns}.${local.site2_domain}.${local.onprem_domain}"), record = local.site2_app1_addr },
  ]
  # hosts redirected to psc endpoint
  onprem_redirected_hosts = [
    {
      hosts = [
        "storage.googleapis.com",
        "bigquery.googleapis.com",
        "${local.hub_eu_region}-aiplatform.googleapis.com",
        "${local.hub_us_region}-aiplatform.googleapis.com",
        "run.app",
      ]
      class = "IN", ttl = "3600", type = "A", record = local.hub_psc_api_all_fr_addr
    },
    # authoritative hosts
    { hosts = [local.hub_eu_psc_https_ctrl_run_dns], class = "IN", ttl = "3600", type = "A", record = local.hub_eu_ilb7_addr },
    { hosts = [local.hub_us_psc_https_ctrl_run_dns], class = "IN", ttl = "3600", type = "A", record = local.hub_us_ilb7_addr },
  ]
  onprem_forward_zones = [
    { zone = "gcp.", targets = [local.hub_eu_ns_addr, local.hub_us_ns_addr] },
    { zone = "${local.hub_psc_api_fr_name}.p.googleapis.com", targets = [local.hub_eu_ns_addr, local.hub_us_ns_addr] },
    { zone = ".", targets = ["8.8.8.8", "8.8.4.4"] },
  ]
}

# site1
#---------------------------------

# unbound config

locals {
  site1_unbound_config = templatefile("../../scripts/startup/unbound/site.sh", {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    FORWARD_ZONES        = local.onprem_forward_zones
  })
}

# addresses

resource "google_compute_address" "site1_router" {
  project = var.project_id_onprem
  name    = "${local.site1_prefix}router"
  region  = local.site1_region
}

# service account

module "site1_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v15.0.0"
  project_id   = var.project_id_onprem
  name         = trimsuffix("${local.site1_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
  }
}

# site2
#---------------------------------

# unbound config

locals {
  site2_unbound_config = templatefile("../../scripts/startup/unbound/site.sh", {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    FORWARD_ZONES        = local.onprem_forward_zones
  })
}

# addresses

resource "google_compute_address" "site2_router" {
  project = var.project_id_onprem
  name    = "${local.site2_prefix}router"
  region  = local.site2_region
}

# service account

module "site2_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v15.0.0"
  project_id   = var.project_id_onprem
  name         = trimsuffix("${local.site2_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
  }
}

# hub
#---------------------------------

data "google_project" "hub_project_number" {
  project_id = var.project_id_hub
}

locals {
  hub_eu_run_flasky_host = module.hub_eu_run_flasky.service.status.0.url
  hub_unbound_config = templatefile("../../scripts/startup/unbound/cloud.sh", {
    FORWARD_ZONES = local.cloud_forward_zones
  })
  cloud_forward_zones = [
    { zone = "onprem.", targets = [local.site1_ns_addr, local.site2_ns_addr] },
    { zone = ".", targets = ["169.254.169.254"] },
  ]
  hub_psc_api_fr_name = (
    local.hub_psc_api_secure ?
    local.hub_psc_api_sec_fr_name :
    local.hub_psc_api_all_fr_name
  )
  hub_psc_api_fr_addr = (
    local.hub_psc_api_secure ?
    local.hub_psc_api_sec_fr_addr :
    local.hub_psc_api_all_fr_addr
  )
  hub_psc_api_fr_target = (
    local.hub_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  hub_psc_api_secure = false
}

# addresses

resource "google_compute_address" "hub_eu_router" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-router"
  region  = local.hub_eu_region
}

resource "google_compute_address" "hub_us_router" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}us-router"
  region  = local.hub_us_region
}

# service account

module "hub_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v15.0.0"
  project_id   = var.project_id_hub
  name         = trimsuffix("${local.hub_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
  }
}

# cloud run

locals {
  hub_eu_run_flasky_port        = 8080
  hub_eu_run_flasky_gcr_host    = "gcr.io"
  hub_eu_run_flasky_repo        = "${local.hub_eu_run_flasky_gcr_host}/${var.project_id_hub}/${local.hub_prefix}flasky:v1"
  hub_eu_run_flasky_repo_create = templatefile("../../templates/run/flasky/create.sh", local.hub_eu_run_flasky_repo_vars)
  hub_eu_run_flasky_repo_delete = templatefile("../../templates/run/flasky/delete.sh", local.hub_eu_run_flasky_repo_vars)
  hub_eu_run_flasky_repo_vars = {
    PROJECT        = var.project_id_hub
    GCR_HOST       = local.hub_eu_run_flasky_gcr_host
    IMAGE_REPO     = local.hub_eu_run_flasky_repo
    CONTAINER_PORT = local.hub_eu_run_flasky_port
    DOCKERFILE_DIR = "../../templates/run/flasky"
  }
}

resource "null_resource" "hub_eu_run_flasky_repo" {
  triggers = {
    create = local.hub_eu_run_flasky_repo_create
    delete = local.hub_eu_run_flasky_repo_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

module "hub_eu_run_flasky" {
  depends_on = [null_resource.hub_eu_run_flasky_repo]
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/cloud-run?ref=v15.0.0"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-run-flasky"
  region     = local.hub_eu_region
  iam        = { "roles/run.invoker" = ["allUsers"] }
  containers = [{
    image         = local.hub_eu_run_flasky_repo
    options       = { command = null, args = null, env = {}, env_from = null }
    ports         = [{ name = "http1", protocol = "TCP", container_port = local.hub_eu_run_flasky_port }]
    resources     = null
    volume_mounts = null
  }]
}

# storage

module "hub_eu_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v15.0.0"
  project_id    = var.project_id_hub
  prefix        = ""
  name          = "${local.hub_prefix}eu-storage-bucket"
  location      = local.hub_eu_region
  storage_class = "STANDARD"
  force_destroy = true
  iam = {
    "roles/storage.objectViewer" = [
      "serviceAccount:${module.site1_sa.email}",
      "serviceAccount:${module.site2_sa.email}",
      "serviceAccount:${module.hub_sa.email}",
    ]
  }
}

resource "google_storage_bucket_object" "hub_eu_storage_bucket_file" {
  name    = "${local.hub_prefix}object.txt"
  bucket  = module.hub_eu_storage_bucket.name
  content = "<--- HUB EU --->"
}

module "hub_us_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v15.0.0"
  project_id    = var.project_id_hub
  prefix        = ""
  name          = "${local.hub_prefix}us-storage-bucket"
  location      = local.hub_us_region
  storage_class = "STANDARD"
  iam = {
    "roles/storage.objectViewer" = [
      "serviceAccount:${module.site1_sa.email}",
      "serviceAccount:${module.site2_sa.email}",
      "serviceAccount:${module.hub_sa.email}",
    ]
  }
}

resource "google_storage_bucket_object" "hub_us_storage_bucket_file" {
  name    = "${local.hub_prefix}object.txt"
  bucket  = module.hub_us_storage_bucket.name
  content = "<--- HUB US --->"
}
