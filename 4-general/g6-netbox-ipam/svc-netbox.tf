
####################################################
# netbox
####################################################

locals {
  netbox_init_dir = "/var/lib/cloudtuple/init"
  netbox_app_dir  = "/var/lib/cloudtuple/netbox"
  netbox_repo     = "https://github.com/netbox-community/netbox-docker.git"
  netbox_init_vars = {
    NETBOX_INIT_DIR = local.netbox_init_dir
    NETBOX_APP_DIR  = local.netbox_app_dir
    NETBOX_REPO     = local.netbox_repo
    NETBOX_PORT     = 8000
  }
  netbox_init_files = {
    "${local.netbox_init_dir}/docker.sh" = { owner = "root", permissions = "0744", content = templatefile("scripts/netbox/docker.sh", local.netbox_init_vars) }
  }
  netbox_startup_init_files = {
    "${local.netbox_app_dir}/netbox.sh" = { owner = "root", permissions = "0744", content = templatefile("scripts/netbox/netbox.sh", local.netbox_init_vars) }
    "${local.netbox_app_dir}/start.sh"  = { owner = "root", permissions = "0744", content = templatefile("scripts/netbox/start.sh", local.netbox_init_vars) }
    "${local.netbox_app_dir}/stop.sh"   = { owner = "root", permissions = "0744", content = templatefile("scripts/netbox/stop.sh", local.netbox_init_vars) }
  }
}

module "netbox_cloud_init" {
  source = "../../modules/cloud-config-gen"
  files = merge(
    local.netbox_init_files,
    local.netbox_startup_init_files
  )
  run_commands = [
    ". ${local.netbox_init_dir}/docker.sh",
    ". ${local.netbox_app_dir}/netbox.sh",
  ]
}

####################################################
# instance
####################################################

module "netbox_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}netbox-vm"
  zone       = "${local.hub_eu_region}-b"
  tags = [
    "egress-internet",
    "ingress-internet",
    "egress-private",
    "ingress-private"
  ]
  tag_bindings_firewall = {
    (local.hub_secure_tags_egress_internet.parent)  = local.hub_secure_tags_egress_internet.id
    (local.hub_secure_tags_egress_private.parent)   = local.hub_secure_tags_egress_private.id
    (local.hub_secure_tags_ingress_internet.parent) = local.hub_secure_tags_ingress_internet.id
    (local.hub_secure_tags_ingress_private.parent)  = local.hub_secure_tags_ingress_private.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
    nat        = true
  }]
  service_account = {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.netbox_cloud_init.cloud_config
  }
}
