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
    { name = "site1-vm     ", host = local.site1_vm_fqdn, ipv4 = local.site1_vm_addr, probe = true, ping = true },
    { name = "hub-eu-vm    ", host = local.hub_eu_vm_fqdn, ipv4 = local.hub_eu_vm_addr, probe = true, ping = true },
    { name = "hub-eu-ilb   ", host = local.hub_eu_ilb_fqdn, ipv4 = local.hub_eu_ilb_addr, },
    { name = "hub-eu-nlb   ", host = local.hub_eu_nlb_fqdn, ipv4 = local.hub_eu_nlb_addr, ipv6 = false },
    { name = "hub-eu-alb   ", host = local.hub_eu_alb_fqdn, ipv4 = local.hub_eu_alb_addr, ipv6 = false },
  ]
  vm_script_targets_region2 = [
    { name = "site2-vm     ", host = local.site2_vm_fqdn, ipv4 = local.site2_vm_addr, probe = true, ping = true },
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
  proxy_startup_files = {
    "${local.init_dir}/unbound/Dockerfile"         = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/unbound/Dockerfile", {}) }
    "${local.init_dir}/unbound/docker-compose.yml" = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/unbound/docker-compose.yml", {}) }
    "${local.init_dir}/unbound/setup-unbound.sh"   = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/unbound/setup-unbound.sh", local.proxy_init_vars) }
    "/etc/unbound/unbound.conf"                    = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/unbound/unbound.conf", local.proxy_init_vars) }

    "${local.init_dir}/squid/docker-compose.yml" = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/squid/docker-compose.yml", local.proxy_init_vars) }
    "${local.init_dir}/squid/setup-squid.sh"     = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/squid/setup-squid.sh", local.proxy_init_vars) }
    "/etc/squid/blocked_sites"                   = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/squid/blocked_sites", local.proxy_init_vars) }
    "/etc/squid/squid.conf"                      = { owner = "root", permissions = "0744", content = templatefile("../../scripts/init/squid/squid.conf", local.proxy_init_vars) }
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
# firewall rules
############################################

locals {
  firewall_policies = {
    site_egress_rules = {
      smtp = {
        priority = 900
        match = {
          destination_ranges = ["0.0.0.0/0"]
          layer4_configs     = [{ protocol = "tcp", ports = ["25"] }]
        }
      }
      all = {
        priority = 910
        action   = "allow"
        match = {
          destination_ranges = ["0.0.0.0/0"]
          layer4_configs     = [{ protocol = "all", ports = [] }]
        }
      }
    }
    site_egress_rules_ipv6 = {
      smtp = {
        priority = 901
        match = {
          destination_ranges = ["0::/0"]
          layer4_configs     = [{ protocol = "tcp", ports = ["25"] }]
        }
      }
      all = {
        priority = 911
        action   = "allow"
        match = {
          destination_ranges = ["0::/0"]
          layer4_configs     = [{ protocol = "all", ports = [] }]
        }
      }
    }
    site_ingress_rules = {
      # ipv4
      internal = {
        priority = 1000
        match = {
          source_ranges  = local.netblocks.internal
          layer4_configs = [{ protocol = "all" }]
        }
      }
      dns = {
        priority = 1100
        match = {
          source_ranges  = local.netblocks.dns
          layer4_configs = [{ protocol = "all", ports = [] }]
        }
      }
      ssh = {
        priority       = 1200
        enable_logging = true
        match = {
          source_ranges  = ["0.0.0.0/0", ]
          layer4_configs = [{ protocol = "tcp", ports = ["22"] }]
        }
      }
      iap = {
        priority       = 1300
        enable_logging = true
        match = {
          source_ranges  = local.netblocks.iap
          layer4_configs = [{ protocol = "all", ports = [] }]
        }
      }
      vpn = {
        priority = 1400
        match = {
          source_ranges = ["0.0.0.0/0", ]
          layer4_configs = [
            { protocol = "udp", ports = ["500", "4500", ] },
            { protocol = "esp", ports = [] }
          ]
        }
      }
      gfe = {
        priority = 1500
        match = {
          source_ranges  = local.netblocks.gfe
          layer4_configs = [{ protocol = "all", ports = [] }]
        }
      }
      # ipv6
      internal-6 = {
        priority = 1001
        match = {
          source_ranges  = local.netblocks_ipv6.internal
          layer4_configs = [{ protocol = "all" }]
        }
      }
      ssh-6 = {
        priority       = 1201
        enable_logging = true
        match = {
          source_ranges  = ["0::/0", ]
          layer4_configs = [{ protocol = "tcp", ports = ["22"] }]
        }
      }
      vpn-6 = {
        priority = 1401
        match = {
          source_ranges = ["0::/0", ]
          layer4_configs = [
            { protocol = "udp", ports = ["500", "4500", ] },
            { protocol = "esp", ports = [] }
          ]
        }
      }
      gfe-6 = {
        priority = 1501
        match = {
          source_ranges  = local.netblocks_ipv6.gfe
          layer4_configs = [{ protocol = "all", ports = [] }]
        }
      }
    }
  }
}

############################################
# addresses
############################################

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
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v34.1.0"
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

# addresses

resource "google_compute_address" "site2_router" {
  project = var.project_id_onprem
  name    = "${local.site2_prefix}router"
  region  = local.site2_region
}

# service account

module "site2_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v34.1.0"
  project_id   = var.project_id_onprem
  name         = trimsuffix("${local.site2_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
  }
}

############################################
# hub
############################################

data "google_project" "hub_project_number" {
  project_id = var.project_id_hub
}

locals {
  hub_unbound_config = templatefile("../../scripts/unbound/unbound.sh", {
    FORWARD_ZONES        = local.cloud_forward_zones
    ONPREM_LOCAL_RECORDS = []
    REDIRECTED_HOSTS     = []
    ACCESS_CONTROL_PREFIXES = concat(
      local.netblocks.internal,
      ["127.0.0.0/8", "35.199.192.0/19", "fd00::/8", ]
    )
  })
  cloud_forward_zones = [
    { zone = "${local.cloud_domain}.", targets = ["169.254.169.254"] },
    { zone = "${local.onprem_domain}.", targets = [local.site1_ns_addr, local.site2_ns_addr] },
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
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v34.1.0"
  project_id   = var.project_id_hub
  name         = trimsuffix("${local.hub_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
  }
}

# cloud run

module "hub_eu_run_httpbin" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/cloud-run-v2?ref=v34.1.0"
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
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v34.1.0"
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
    ]
  }
}

resource "google_storage_bucket_object" "hub_eu_storage_bucket_file" {
  name    = "${local.hub_prefix}object.txt"
  bucket  = module.hub_eu_storage_bucket.name
  content = "<--- HUB EU --->"
}

module "hub_us_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v34.1.0"
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

####################################################
# output files
####################################################

locals {
  main_files = {
    "output/server.sh"              = local.vm_startup
    "output/startup.sh"             = templatefile("../../scripts/startup.sh", local.vm_init_vars)
    "output/startup-probe.sh"       = templatefile("../../scripts/startup.sh", local.probe_init_vars)
    "output/probe-cloud-config.yml" = module.probe_vm_cloud_init.cloud_config
    "output/vm-cloud-config.yml"    = module.vm_cloud_init.cloud_config
  }
}

resource "local_file" "main_files" {
  for_each = local.main_files
  filename = each.key
  content  = each.value
}
