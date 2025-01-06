####################################################
# lab
####################################################

locals {
  eu_ar_host   = "eu-docker.pkg.dev"
  us_ar_host   = "us-docker.pkg.dev"
  eu_repo_name = google_artifact_registry_repository.eu_repo.name
  us_repo_name = google_artifact_registry_repository.us_repo.name
  httpbin_port = 80

  hub_psc_api_secure = false

  hub_eu_run_httpbin_host = module.hub_eu_run_httpbin.service.uri

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
    { name = "hub-eu-psc-https", host = local.hub_eu_psc_https_ctrl_run_dns, path = "/generate_204" },
    { name = "hub-us-psc-https", host = local.hub_us_psc_https_ctrl_run_dns, path = "/generate_204" },
    { name = "hub-eu-run", host = local.hub_eu_run_httpbin_host, probe = true, path = "/generate_204" },
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
      local.netblocks.internal,
      ["127.0.0.0/8", "35.199.192.0/19", "fd00::/8", ]
    )
  }
  app_init_vars = {
    health_check_path     = local.uhc_config.request_path
    health_check_response = local.uhc_config.response
  }
  vm_init_files = {
    "${local.init_dir}/fastapi/docker-compose-http-80.yml"   = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/fastapi/docker-compose-http-80.yml", {}) }
    "${local.init_dir}/fastapi/docker-compose-http-8080.yml" = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/fastapi/docker-compose-http-8080.yml", {}) }
    "${local.init_dir}/fastapi/app/app/Dockerfile"           = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/fastapi/app/app/Dockerfile", {}) }
    "${local.init_dir}/fastapi/app/app/_app.py"              = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/fastapi/app/app/_app.py", {}) }
    "${local.init_dir}/fastapi/app/app/main.py"              = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/fastapi/app/app/main.py", {}) }
    "${local.init_dir}/fastapi/app/app/requirements.txt"     = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/fastapi/app/app/requirements.txt", {}) }
  }
  vm_startup_init_files = {
    "${local.init_dir}/init/startup.sh" = { owner = "root", permissions = "0744", content = templatefile("../../scripts/startup.sh", local.vm_init_vars) }
  }
  probe_startup_init_files = {
    "${local.init_dir}/init/startup.sh" = { owner = "root", permissions = "0744", content = templatefile("../../scripts/startup.sh", local.probe_init_vars) }
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
    "HOSTNAME=$(hostname) docker compose -f ${local.init_dir}/fastapi/docker-compose-http-80.yml up -d",
    "HOSTNAME=$(hostname) docker compose -f ${local.init_dir}/fastapi/docker-compose-http-8080.yml up -d",
  ]
}

module "probe_vm_cloud_init" {
  source = "../../modules/cloud-config-gen"
  files = merge(
    local.vm_init_files,
    local.probe_startup_init_files,
  )
  run_commands = [
    ". ${local.init_dir}/init/startup.sh",
    "HOSTNAME=$(hostname) docker compose -f ${local.init_dir}/fastapi/docker-compose-http-80.yml up -d",
    "HOSTNAME=$(hostname) docker compose -f ${local.init_dir}/fastapi/docker-compose-http-8080.yml up -d",
  ]
}

module "proxy_vm_cloud_init" {
  source = "../../modules/cloud-config-gen"
  files  = local.proxy_startup_files
  run_commands = [
    "sysctl -w net.ipv4.ip_forward=1",
    "sysctl -w net.ipv4.conf.eth0.disable_xfrm=1",
    "sysctl -w net.ipv4.conf.eth0.disable_policy=1",
    "echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf",
    "sysctl -w net.ipv6.conf.all.forwarding=1",
    "echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf",
    "sysctl -p",
    "echo iptables-persistent iptables-persistent/autosave_v4 boolean false | debconf-set-selections",
    "echo iptables-persistent iptables-persistent/autosave_v6 boolean false | debconf-set-selections",
    "apt-get -y install iptables-persistent",
    "iptables -P FORWARD ACCEPT",
    "iptables -P INPUT ACCEPT",
    "iptables -P OUTPUT ACCEPT",
    "iptables -t nat -A POSTROUTING -d 10.0.0.0/8 -j ACCEPT",
    "iptables -t nat -A POSTROUTING -d 172.16.0.0/12 -j ACCEPT",
    "iptables -t nat -A POSTROUTING -d 192.168.0.0/16 -j ACCEPT",
    "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE",
    ". ${local.init_dir}/init/startup.sh",
    ". ${local.init_dir}/unbound/setup-unbound.sh",
    ". ${local.init_dir}/squid/setup-squid.sh",
    "docker compose -f ${local.init_dir}/unbound/docker-compose.yml up -d",
    "docker compose -f ${local.init_dir}/squid/docker-compose.yml up -d",
  ]
}

############################################
# hub
############################################

# service account

module "hub_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v36.0.1"
  project_id   = var.project_id_hub
  name         = trimsuffix("${local.hub_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
  }
}

####################################################
# output files
####################################################

locals {
  main_files = {
    "output/server.sh"           = local.vm_startup
    "output/startup.sh"          = templatefile("../../scripts/startup.sh", local.vm_init_vars)
    "output/vm-cloud-config.yml" = module.vm_cloud_init.cloud_config
  }
}

resource "local_file" "main_files" {
  for_each = local.main_files
  filename = each.key
  content  = each.value
}
