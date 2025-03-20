####################################################
# lab
####################################################

locals {
  eu_ar_host   = "eu-docker.pkg.dev"
  us_ar_host   = "us-docker.pkg.dev"
  eu_repo_name = google_artifact_registry_repository.eu_repo.name
  us_repo_name = google_artifact_registry_repository.us_repo.name
  httpbin_port = 80

  hub_psc_ep_api_secure = false
  hub_psc_ep_api_fr_name = (
    local.hub_psc_ep_api_secure ?
    local.hub_psc_ep_api_sec_fr_name :
    local.hub_psc_ep_api_all_fr_name
  )
  hub_psc_ep_api_fr_addr = (
    local.hub_psc_ep_api_secure ?
    local.hub_psc_ep_api_sec_fr_addr :
    local.hub_psc_ep_api_all_fr_addr
  )
  hub_psc_ep_api_fr_target = (
    local.hub_psc_ep_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  enable_ipv6 = true
}

####################################################
# common resources
####################################################

# artifacts registry

resource "google_artifact_registry_repository" "eu_repo" {
  project       = var.project_id_hub
  location      = local.hub_eu_region
  repository_id = "${local.hub_prefix}eu-repo"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository" "us_repo" {
  project       = var.project_id_hub
  location      = local.hub_us_region
  repository_id = "${local.hub_prefix}us-repo"
  format        = "DOCKER"
}

####################################################
# vm startup scripts
####################################################

locals {
  init_dir = "/var/lib/gcp"
  WEB_SERVER = {
    server_port           = local.svc_web.port
    health_check_path     = local.uhc_config.request_path
    health_check_response = local.uhc_config.response
  }
  vm_script_targets_region1 = []
  vm_script_targets_region2 = []
  vm_script_targets_misc    = []
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
  probe_init_vars = {
    TARGETS                   = local.vm_script_targets
    TARGETS_LIGHT_TRAFFIC_GEN = local.vm_script_targets
    TARGETS_HEAVY_TRAFFIC_GEN = [for target in local.vm_script_targets : target.host if try(target.probe, false)]
  }
  vm_init_vars = {
    TARGETS                   = local.vm_script_targets
    TARGETS_LIGHT_TRAFFIC_GEN = []
    TARGETS_HEAVY_TRAFFIC_GEN = []
  }
  proxy_init_vars = {
    ONPREM_LOCAL_RECORDS = []
    REDIRECTED_HOSTS     = []
    FORWARD_ZONES        = []
    TARGETS              = local.vm_script_targets
    ACCESS_CONTROL_PREFIXES = concat(
      local.netblocks_internal,
      ["127.0.0.0/8", "35.199.192.0/19", "fd00::/8", ]
    )
  }
  app_init_vars = {
    health_check_path     = local.uhc_config.request_path
    health_check_response = local.uhc_config.response
  }
  vm_init_files            = {}
  vm_startup_init_files    = {}
  probe_startup_init_files = {}
}

module "vm_cloud_init" {
  source = "../../modules/cloud-config-gen"
  files = merge(
    local.vm_init_files,
    local.vm_startup_init_files
  )
  run_commands = []
}

############################################
# hub
############################################

data "google_project" "hub_project_number" {
  project_id = var.project_id_hub
}

# service account

module "hub_sa" {
  source     = "../../modules/iam-service-account"
  project_id = var.project_id_hub
  name       = trimsuffix("${local.hub_prefix}sa", "-")
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
  }
}

####################################################
# output files
####################################################

locals {
  main_files = {}
}

resource "local_file" "main_files" {
  for_each = local.main_files
  filename = each.key
  content  = each.value
}
