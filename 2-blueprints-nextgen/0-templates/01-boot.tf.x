
# common
#---------------------------------

locals {
  vm_startup = templatefile("../scripts/startup/gce.sh", {
    ENABLE_PROBES = true
    SCRIPTS = {
      targets_curl_dns   = local.targets_curl_dns
      targets_ping_dns  = local.targets_ping_dns
      targets_pga   = local.targets_pga
      targets_psc   = local.targets_psc
      targets_probe = concat(local.targets_curl_dns, local.targets_pga)
      targets_bucket = {
        ("hub")    = module.hub_eu_storage_bucket.name
        ("spoke1") = module.spoke1_eu_storage_bucket.name
        ("spoke2") = module.spoke2_us_storage_bucket.name
      }
      targets_ai_project = [{ project = var.project_id_hub, region = local.hub_eu_region }, ]
    }
    WEB_SERVER = {
      port                  = local.svc_web.port
      health_check_path     = local.uhc_config.request_path
      health_check_response = local.uhc_config.response
    }
  })
  td_client_startup = templatefile("../scripts/startup/client.sh", {
    TD_PROJECT_NUMBER = data.google_project.spoke2_project_number.number
    TD_NETWORK_NAME   = "${local.spoke2_prefix}vpc"
    TARGETS_GRPC      = local.targets_grpc
    TARGETS_ENVOY     = local.targets_td
  })
  targets_psc = [
    "${local.hub_us_psc4_consumer_spoke2_us_svc_dns}.${local.hub_psc_domain}:${local.svc_web.port}",
    "${local.spoke1_us_psc4_consumer_spoke2_us_svc_dns}.${local.spoke1_psc_domain}:${local.svc_web.port}",
  ]
  targets_td = [
    "${local.spoke2_td_envoy_bridge_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke2_td_envoy_cloud_svc}.${local.spoke2_td_domain}:${local.svc_web.port}",
    "${local.spoke2_td_envoy_hybrid_svc}.${local.spoke2_td_domain}:${local.svc_web.port}",
  ]
  targets_grpc = [
    "${local.spoke2_td_grpc_cloud_svc}.${local.spoke2_td_domain}"
  ]
  sql_access_via_local_host = [
    {
      script_name = "sql_local_eu"
      project     = var.project_id_spoke1
      region      = local.spoke1_eu_region
      instance    = local.spoke1_eu_cloudsql_name
      port        = 3306
      user        = "admin"
      password    = local.spoke1_cloudsql_users.admin.password
    },
    {
      script_name = "sql_local_us"
      project     = var.project_id_spoke1
      region      = local.spoke1_us_region
      instance    = local.spoke1_us_cloudsql_name
      port        = 3306
      user        = "admin"
      password    = local.spoke1_cloudsql_users.admin.password
    },
  ]
  sql_access_via_proxy = [
    {
      script_name  = "sql_proxy_eu"
      sql_proxy_ip = local.spoke1_eu_sql_proxy_addr
      port         = 3306
      user         = "admin"
      password     = local.spoke1_cloudsql_users.admin.password
    },
    {
      script_name  = "sql_proxy_us"
      sql_proxy_ip = local.spoke1_us_sql_proxy_addr
      port         = 3306
      user         = "admin"
      password     = local.spoke1_cloudsql_users.admin.password
    },
  ]
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
    { hosts = [local.spoke1_eu_psc_https_ctrl_run_dns], class = "IN", ttl = "3600", type = "A", record = local.spoke1_eu_ilb7_addr },
    { hosts = [local.spoke2_us_psc_https_ctrl_run_dns], class = "IN", ttl = "3600", type = "A", record = local.spoke2_us_ilb7_addr },
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
  site1_unbound_config = templatefile("../scripts/startup/unbound/site.sh", {
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
    (var.project_id_spoke1) = ["roles/owner", ]
    (var.project_id_spoke2) = ["roles/owner", ]
  }
}

# site2
#---------------------------------

# unbound config

locals {
  site2_unbound_config = templatefile("../scripts/startup/unbound/site.sh", {
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
    (var.project_id_spoke1) = ["roles/owner", ]
    (var.project_id_spoke2) = ["roles/owner", ]
  }
}

# hub
#---------------------------------

data "google_project" "hub_project_number" {
  project_id = var.project_id_hub
}

locals {
  hub_eu_run_flasky_host = module.hub_eu_run_flasky.service.status.0.url
  hub_unbound_config = templatefile("../scripts/startup/unbound/cloud.sh", {
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
    (var.project_id_spoke1) = ["roles/owner", ]
    (var.project_id_spoke2) = ["roles/owner", ]
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
    image         = "kennethreitz/httpbin"
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
  prefix        = null
  name          = "${local.hub_prefix}eu-storage-bucket"
  location      = local.hub_eu_region
  storage_class = "STANDARD"
  force_destroy = true
  iam = {
    "roles/storage.objectViewer" = [
      "serviceAccount:${module.site1_sa.email}",
      "serviceAccount:${module.site2_sa.email}",
      "serviceAccount:${module.hub_sa.email}",
      "serviceAccount:${module.spoke1_sa.email}",
      "serviceAccount:${module.spoke2_sa.email}",
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
  prefix        = null
  name          = "${local.hub_prefix}us-storage-bucket"
  location      = local.hub_us_region
  storage_class = "STANDARD"
  iam = {
    "roles/storage.objectViewer" = [
      "serviceAccount:${module.site1_sa.email}",
      "serviceAccount:${module.site2_sa.email}",
      "serviceAccount:${module.hub_sa.email}",
      "serviceAccount:${module.spoke1_sa.email}",
      "serviceAccount:${module.spoke2_sa.email}",
    ]
  }
}

resource "google_storage_bucket_object" "hub_us_storage_bucket_file" {
  name    = "${local.hub_prefix}object.txt"
  bucket  = module.hub_us_storage_bucket.name
  content = "<--- HUB US --->"
}

# host
#---------------------------------

data "google_project" "host_project_number" {
  project_id = var.project_id_host
}


# spoke1
#---------------------------------

data "google_project" "spoke1_project_number" {
  project_id = var.project_id_spoke1
}

locals {
  spoke1_eu_run_flasky_host = module.spoke1_eu_run_flasky.service.status.0.url
  spoke1_psc_api_fr_name = (
    local.spoke1_psc_api_secure ?
    local.spoke1_psc_api_sec_fr_name :
    local.spoke1_psc_api_all_fr_name
  )
  spoke1_psc_api_fr_addr = (
    local.spoke1_psc_api_secure ?
    local.spoke1_psc_api_sec_fr_addr :
    local.spoke1_psc_api_all_fr_addr
  )
  spoke1_psc_api_fr_target = (
    local.spoke1_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  spoke1_psc_api_secure = true
}

# service account

module "spoke1_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v15.0.0"
  project_id   = var.project_id_spoke1
  name         = trimsuffix("${local.spoke1_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
    (var.project_id_spoke1) = ["roles/owner", ]
    (var.project_id_spoke2) = ["roles/owner", ]
  }
}

# cloud run

locals {
  spoke1_eu_run_flasky_port        = 8080
  spoke1_eu_run_flasky_gcr_host    = "gcr.io"
  spoke1_eu_run_flasky_repo        = "${local.spoke1_eu_run_flasky_gcr_host}/${var.project_id_spoke1}/${local.spoke1_prefix}flasky:v1"
  spoke1_eu_run_flasky_repo_create = templatefile("../../templates/run/flasky/create.sh", local.spoke1_eu_run_flasky_repo_vars)
  spoke1_eu_run_flasky_repo_delete = templatefile("../../templates/run/flasky/delete.sh", local.spoke1_eu_run_flasky_repo_vars)
  spoke1_eu_run_flasky_repo_vars = {
    PROJECT        = var.project_id_spoke1
    GCR_HOST       = local.spoke1_eu_run_flasky_gcr_host
    IMAGE_REPO     = local.spoke1_eu_run_flasky_repo
    CONTAINER_PORT = local.spoke1_eu_run_flasky_port
    DOCKERFILE_DIR = "../../templates/run/flasky"
  }
}

resource "null_resource" "spoke1_eu_run_flasky_repo" {
  depends_on = [null_resource.hub_eu_run_flasky_repo]
  triggers = {
    create = local.spoke1_eu_run_flasky_repo_create
    delete = local.spoke1_eu_run_flasky_repo_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

module "spoke1_eu_run_flasky" {
  depends_on = [null_resource.spoke1_eu_run_flasky_repo]
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/cloud-run?ref=v15.0.0"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}eu-run-flasky"
  region     = local.spoke1_eu_region
  iam        = { "roles/run.invoker" = ["allUsers"] }
  containers = [{
    image         = "kennethreitz/httpbin"
    options       = { command = null, args = null, env = {}, env_from = null }
    ports         = [{ name = "http1", protocol = "TCP", container_port = local.spoke1_eu_run_flasky_port }]
    resources     = null
    volume_mounts = null
  }]
}

# storage

module "spoke1_eu_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v15.0.0"
  project_id    = var.project_id_spoke1
  prefix        = null
  name          = "${local.spoke1_prefix}eu-storage-bucket"
  location      = local.spoke1_eu_region
  storage_class = "STANDARD"
  force_destroy = true
  iam = {
    "roles/storage.objectViewer" = [
      "serviceAccount:${module.site1_sa.email}",
      "serviceAccount:${module.site2_sa.email}",
      "serviceAccount:${module.hub_sa.email}",
      "serviceAccount:${module.spoke1_sa.email}",
      "serviceAccount:${module.spoke2_sa.email}",
    ]
  }
}

resource "google_storage_bucket_object" "spoke1_eu_storage_bucket_file" {
  name    = "${local.spoke1_prefix}object.txt"
  bucket  = module.spoke1_eu_storage_bucket.name
  content = "<--- SPOKE 1 --->"
}

# spoke2
#---------------------------------

data "google_project" "spoke2_project_number" {
  project_id = var.project_id_spoke2
}

locals {
  spoke2_us_run_flasky_host = module.spoke2_us_run_flasky.service.status.0.url
  spoke2_psc_api_fr_name = (
    local.spoke2_psc_api_secure ?
    local.spoke2_psc_api_sec_fr_name :
    local.spoke2_psc_api_all_fr_name
  )
  spoke2_psc_api_fr_addr = (
    local.spoke2_psc_api_secure ?
    local.spoke2_psc_api_sec_fr_addr :
    local.spoke2_psc_api_all_fr_addr
  )
  spoke2_psc_api_fr_target = (
    local.spoke2_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  spoke2_psc_api_secure = true
}

# service account

module "spoke2_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v15.0.0"
  project_id   = var.project_id_spoke2
  name         = trimsuffix("${local.spoke2_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
    (var.project_id_spoke1) = ["roles/owner", ]
    (var.project_id_spoke2) = ["roles/owner", ]
  }
}

# cloud run

locals {
  spoke2_us_run_flasky_port        = 8080
  spoke2_us_run_flasky_gcr_host    = "gcr.io"
  spoke2_us_run_flasky_repo        = "${local.spoke2_us_run_flasky_gcr_host}/${var.project_id_spoke2}/${local.spoke2_prefix}flasky:v1"
  spoke2_us_run_flasky_repo_create = templatefile("../../templates/run/flasky/create.sh", local.spoke2_us_run_flasky_repo_vars)
  spoke2_us_run_flasky_repo_delete = templatefile("../../templates/run/flasky/delete.sh", local.spoke2_us_run_flasky_repo_vars)
  spoke2_us_run_flasky_repo_vars = {
    PROJECT        = var.project_id_spoke2
    GCR_HOST       = local.spoke2_us_run_flasky_gcr_host
    IMAGE_REPO     = local.spoke2_us_run_flasky_repo
    CONTAINER_PORT = local.spoke2_us_run_flasky_port
    DOCKERFILE_DIR = "../../templates/run/flasky"
  }
}

resource "null_resource" "spoke2_us_run_flasky_repo" {
  depends_on = [null_resource.spoke1_eu_run_flasky_repo]
  triggers = {
    create = local.spoke2_us_run_flasky_repo_create
    delete = local.spoke2_us_run_flasky_repo_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

module "spoke2_us_run_flasky" {
  # depends_on = [null_resource.spoke2_us_run_flasky_repo]
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/cloud-run?ref=v15.0.0"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}us-run-flasky"
  region     = local.spoke2_us_region
  iam        = { "roles/run.invoker" = ["allUsers"] }
  containers = [{
    image         = "kennethreitz/httpbin"
    options       = { command = null, args = null, env = {}, env_from = null }
    ports         = [{ name = "http1", protocol = "TCP", container_port = local.spoke2_us_run_flasky_port }]
    resources     = null
    volume_mounts = null
  }]
}

# storage

module "spoke2_us_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v15.0.0"
  project_id    = var.project_id_spoke2
  prefix        = null
  name          = "${local.spoke2_prefix}us-storage-bucket"
  location      = local.spoke2_us_region
  storage_class = "STANDARD"
  force_destroy = true
  iam = {
    "roles/storage.objectViewer" = [
      "serviceAccount:${module.site1_sa.email}",
      "serviceAccount:${module.site2_sa.email}",
      "serviceAccount:${module.hub_sa.email}",
      "serviceAccount:${module.spoke1_sa.email}",
      "serviceAccount:${module.spoke2_sa.email}",
    ]
  }
}

resource "google_storage_bucket_object" "spoke2_us_storage_bucket_file" {
  name    = "${local.spoke2_prefix}object.txt"
  bucket  = module.spoke2_us_storage_bucket.name
  content = "<--- SPOKE 2 --->"
}
