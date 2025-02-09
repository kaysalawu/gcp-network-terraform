####################################################
# lab
####################################################

locals {
  eu_ar_host   = "eu-docker.pkg.dev"
  us_ar_host   = "us-docker.pkg.dev"
  eu_repo_name = google_artifact_registry_repository.eu_repo.name
  httpbin_port = 80

  hub_psc_api_secure = false
  enable_ipv6        = true
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
  vm_script_targets_region1 = [
    { name = "hub-eu-vm    ", host = local.hub_eu_vm_fqdn, ipv4 = local.hub_eu_vm_addr, probe = true, ping = true },
    { name = "hub-eu-ilb   ", host = local.hub_eu_ilb_fqdn, ipv4 = local.hub_eu_ilb_addr, },
    { name = "hub-eu-nlb   ", host = local.hub_eu_nlb_fqdn, ipv4 = local.hub_eu_nlb_addr, ipv6 = false },
    { name = "hub-eu-alb   ", host = local.hub_eu_alb_fqdn, ipv4 = local.hub_eu_alb_addr, ipv6 = false },
  ]
  vm_script_targets_region2 = [
    { name = "hub-us-vm    ", host = local.hub_us_vm_fqdn, ipv4 = local.hub_us_vm_addr, probe = true, ping = true },
    { name = "hub-us-ilb   ", host = local.hub_us_ilb_fqdn, ipv4 = local.hub_us_ilb_addr },
    { name = "hub-us-nlb   ", host = local.hub_us_nlb_fqdn, ipv4 = local.hub_us_nlb_addr, ipv6 = false },
    { name = "hub-us-alb   ", host = local.hub_us_alb_fqdn, ipv4 = local.hub_us_alb_addr, ipv6 = false },
  ]
  vm_script_targets_misc = [
    { name = "hub-geo-ilb", host = local.hub_geo_ilb_fqdn },
    { name = "internet", host = "icanhazip.com", probe = true },
    { name = "www", host = "www.googleapis.com", path = "/generate_204", probe = true },
    { name = "storage", host = "storage.googleapis.com", path = "/generate_204", probe = true },
    { name = "hub-eu-psc-https", host = local.hub_eu_psc_be_run_dns, path = "/generate_204" },
    { name = "hub-us-psc-https", host = local.hub_us_psc_be_run_dns, path = "/generate_204" },
  ]
  vm_script_targets = concat(
    local.vm_script_targets_region1,
    local.vm_script_targets_region2,
    local.vm_script_targets_misc,
  )
  vm_init_vars = {
    NEO4J_USERNAME = var.neo4j_db_username
    NEO4J_PASSWORD = var.neo4j_db_password
    NEO4J_URI      = var.neo4j_db_uri
  }
  vm_init_files = {
    "${local.init_dir}/neo4j/Dockerfile"       = { owner = "root", permissions = "0744", content = templatefile("./scripts/init/neo4j/Dockerfile", {}) }
    "${local.init_dir}/neo4j/client.py"        = { owner = "root", permissions = "0744", content = templatefile("./scripts/init/neo4j/client.py", local.vm_init_vars) }
    "${local.init_dir}/neo4j/query.py"         = { owner = "root", permissions = "0744", content = templatefile("./scripts/init/neo4j/query.py", local.vm_init_vars) }
    "${local.init_dir}/neo4j/devenv.txt"       = { owner = "root", permissions = "0744", content = templatefile("./scripts/init/neo4j/devenv.txt", local.vm_init_vars) }
    "${local.init_dir}/neo4j/requirements.txt" = { owner = "root", permissions = "0744", content = templatefile("./scripts/init/neo4j/requirements.txt", {}) }
  }
  vm_startup_init_files = {
    "${local.init_dir}/init/startup.sh" = { owner = "root", permissions = "0744", content = templatefile("./scripts/startup.sh", local.vm_init_vars) }
  }
}

module "vm_cloud_init" {
  source = "../../modules/cloud-config-gen"
  files = merge(
    local.vm_init_files,
    local.vm_startup_init_files
  )
  run_commands = [
    ". ${local.init_dir}/init/startup.sh",
  ]
}

############################################
# hub
############################################

locals {
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

# service account

module "hub_sa" {
  source       = "../../modules/iam-service-account"
  project_id   = var.project_id_hub
  name         = trimsuffix("${local.hub_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_hub) = ["roles/owner", ]
  }
}

####################################################
# output files
####################################################

locals {
  main_files = {
    "output/startup.sh" = templatefile("./scripts/startup.sh", local.vm_init_vars)
  }
}

resource "local_file" "main_files" {
  for_each = local.main_files
  filename = each.key
  content  = each.value
}
