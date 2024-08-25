####################################################
# lab
####################################################

locals {
  prefix       = "a"
  eu_ar_host   = "eu-docker.pkg.dev"
  us_ar_host   = "us-docker.pkg.dev"
  eu_repo_name = google_artifact_registry_repository.eu_repo.name
  us_repo_name = google_artifact_registry_repository.us_repo.name
  httpbin_port = 80

  hub_psc_api_secure    = false
  spoke1_psc_api_secure = true
  spoke2_psc_api_secure = true

  hub_eu_run_httpbin_host    = module.hub_eu_run_httpbin.service.uri
  spoke1_eu_run_httpbin_host = module.spoke1_eu_run_httpbin.service.uri
  spoke2_us_run_httpbin_host = module.spoke2_us_run_httpbin.service.uri

  enable_ipv6 = false
}

####################################################
# common resources
####################################################

# artifacts registry

resource "google_artifact_registry_repository" "eu_repo" {
  project       = var.project_id_hub
  location      = local.hub_eu_region
  repository_id = "${local.prefix}-eu-repo"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository" "us_repo" {
  project       = var.project_id_hub
  location      = local.hub_us_region
  repository_id = "${local.prefix}-us-repo"
  format        = "DOCKER"
}

# vm startup scripts
#----------------------------

locals {
  init_dir = "/var/lib/gcp"
  vm_script_targets_region1 = [
    { name = "site1-vm      ", host = local.site1_vm_fqdn, ipv4 = local.site1_vm_addr, ipv6 = local.site1_vm_addr_v6, probe = false },
    { name = "hub-eu-vm     ", host = local.hub_eu_vm_fqdn, ipv4 = local.hub_eu_vm_addr, ipv6 = local.hub_eu_vm_addr_v6, probe = false },
    { name = "spoke1-eu-vm  ", host = local.spoke1_eu_vm_fqdn, ipv4 = local.spoke1_eu_vm_addr, ipv6 = local.spoke1_eu_vm_addr_v6, probe = false },
    { name = "spoke2-eu-vm  ", host = local.spoke2_eu_vm_fqdn, ipv4 = local.spoke2_eu_vm_addr, ipv6 = local.spoke2_eu_vm_addr_v6, probe = false },
    { name = "hub-eu-ilb4   ", host = local.hub_eu_ilb4_fqdn, ipv4 = local.hub_eu_ilb4_addr, ipv6 = local.hub_eu_ilb4_addr_v6, probe = false },
    { name = "hub-eu-ilb7   ", host = local.hub_eu_ilb7_fqdn, ipv4 = local.hub_eu_ilb7_addr, ipv6 = local.hub_eu_ilb7_addr_v6, probe = false },
    { name = "spoke1-eu-ilb4", host = local.spoke1_eu_ilb4_fqdn, ipv4 = local.spoke1_eu_ilb4_addr, ipv6 = local.spoke1_eu_ilb4_addr_v6, probe = false },
    { name = "spoke1-eu-ilb7", host = local.spoke1_eu_ilb7_fqdn, ipv4 = local.spoke1_eu_ilb7_addr, ipv6 = local.spoke1_eu_ilb7_addr_v6, probe = false },
  ]
  vm_script_targets_region2 = [
    { name = "site2-vm      ", host = local.site2_vm_fqdn, ipv4 = local.site2_vm_addr, ipv6 = local.site2_vm_addr_v6, probe = false },
    { name = "hub-us-vm     ", host = local.hub_us_vm_fqdn, ipv4 = local.hub_us_vm_addr, ipv6 = local.hub_us_vm_addr_v6, probe = false },
    { name = "spoke2-us-vm  ", host = local.spoke2_us_vm_fqdn, ipv4 = local.spoke2_us_vm_addr, ipv6 = local.spoke2_us_vm_addr_v6, probe = false },
    { name = "hub-us-ilb4   ", host = local.hub_us_ilb4_fqdn, ipv4 = local.hub_us_ilb4_addr, ipv6 = local.hub_us_ilb4_addr_v6, probe = false },
    { name = "hub-us-ilb7   ", host = local.hub_us_ilb7_fqdn, ipv4 = local.hub_us_ilb7_addr, ipv6 = local.hub_us_ilb7_addr_v6, probe = false },
    { name = "spoke2-us-ilb4", host = local.spoke2_us_ilb4_fqdn, ipv4 = local.spoke2_us_ilb4_addr, ipv6 = local.spoke2_us_ilb4_addr_v6, probe = false },
    { name = "spoke2-us-ilb7", host = local.spoke2_us_ilb7_fqdn, ipv4 = local.spoke2_us_ilb7_addr, ipv6 = local.spoke2_us_ilb7_addr_v6, probe = false },
  ]
  vm_script_targets_misc = [
    { name = "internet", host = "icanhazip.com", ipv4 = "icanhazip.com", ipv6 = "icanhazip.com" },
    { name = "www", host = "www.googleapis.com", ipv4 = "www.googleapis.com", ipv6 = "www.googleapis.com", path = "/generate_204" },
    { name = "storage", host = "storage.googleapis.com", ipv4 = "storage.googleapis.com", ipv6 = "storage.googleapis.com", path = "/generate_204" },
    { name = "hub-eu-psc-https", host = "${local.hub_eu_psc_https_ctrl_run_dns}", probe = false },
    { name = "hub-us-psc-https", host = "${local.hub_us_psc_https_ctrl_run_dns}", probe = false },
    { name = "hub-eu-run", host = "${local.hub_eu_run_httpbin_host}", probe = false, path = "/generate_204" },
    { name = "spoke1-eu-run", host = "${local.spoke1_eu_run_httpbin_host}", probe = false, path = "/generate_204" },
    { name = "spoke2-us-run", host = "${local.spoke2_us_run_httpbin_host}", probe = false, path = "/generate_204" },
  ]
  vm_script_targets = concat(
    local.vm_script_targets_region1,
    local.vm_script_targets_region2,
    local.vm_script_targets_misc,
  )
  vm_startup = templatefile("../../scripts/server.sh", {
    TARGETS                   = local.vm_script_targets
    TARGETS_LIGHT_TRAFFIC_GEN = []
    TARGETS_HEAVY_TRAFFIC_GEN = []
    ENABLE_TRAFFIC_GEN        = false
  })
  WEB_SERVER = {
    server_port           = local.svc_web.port
    health_check_path     = local.uhc_config.request_path
    health_check_response = local.uhc_config.response
  }
}

############################################
# on-premises
############################################

# unbound config
#---------------------------------

locals {
  onprem_local_records = [
    { name = local.site1_vm_fqdn, record = local.site1_vm_addr },
    { name = local.site2_vm_fqdn, record = local.site2_vm_addr },
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

# addresses

resource "google_compute_address" "site1_router" {
  project = var.project_id_onprem
  name    = "${local.site1_prefix}router"
  region  = local.site1_region
}

# service account

module "site1_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v33.0.0"
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

# addresses

resource "google_compute_address" "site2_router" {
  project = var.project_id_onprem
  name    = "${local.site2_prefix}router"
  region  = local.site2_region
}

# service account

module "site2_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v33.0.0"
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

############################################
# hub
############################################

data "google_project" "hub_project_number" {
  project_id = var.project_id_hub
}

locals {
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
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v33.0.0"
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

module "hub_eu_run_httpbin" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/cloud-run-v2?ref=v33.0.0"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}us-run-httpbin"
  region     = local.hub_eu_region
  iam        = { "roles/run.invoker" = ["allUsers"] }
  containers = {
    httpbin = {
      image = "kennethreitz/httpbin"
      ports = {
        httpbin = { name = "http1", container_port = local.httpbin_port }
      }
      resources     = null
      volume_mounts = null
    }
  }
}

# storage

module "hub_eu_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v33.0.0"
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
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v33.0.0"
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

############################################
# host
############################################

data "google_project" "host_project_number" {
  project_id = var.project_id_host
}

############################################
# spoke1
############################################

data "google_project" "spoke1_project_number" {
  project_id = var.project_id_spoke1
}

locals {
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
}

# service account

module "spoke1_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v33.0.0"
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

module "spoke1_eu_run_httpbin" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/cloud-run-v2?ref=v33.0.0"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}eu-run-httpbin"
  region     = local.spoke1_eu_region
  iam        = { "roles/run.invoker" = ["allUsers"] }
  containers = {
    httpbin = {
      image = "kennethreitz/httpbin"
      ports = {
        httpbin = { name = "http1", container_port = local.httpbin_port }
      }
      resources     = null
      volume_mounts = null
    }
  }
}

# storage

module "spoke1_eu_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v33.0.0"
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

############################################
# spoke2
############################################

data "google_project" "spoke2_project_number" {
  project_id = var.project_id_spoke2
}

locals {
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
}

# service account

module "spoke2_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v33.0.0"
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

module "spoke2_us_run_httpbin" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/cloud-run-v2?ref=v33.0.0"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}us-run-httpbin"
  region     = local.spoke2_us_region
  iam        = { "roles/run.invoker" = ["allUsers"] }
  containers = {
    httpbin = {
      image = "kennethreitz/httpbin"
      ports = {
        httpbin = { name = "http1", container_port = local.httpbin_port }
      }
      resources     = null
      volume_mounts = null
    }
  }
}

# storage

module "spoke2_us_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v33.0.0"
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

####################################################
# output files
####################################################

locals {
  main_files = {
    "output/vm-startup.sh" = local.vm_startup
    # "output/site1-unbound.sh" = local.site1_unbound_config
    # "output/site2-unbound.sh" = local.site2_unbound_config
  }
}

resource "local_file" "main_files" {
  for_each = local.main_files
  filename = each.key
  content  = each.value
}
