
locals {
  site1_regions = [local.site1_region, ]
  site1_subnet1 = google_compute_subnetwork.site1_subnets["${local.site1_prefix}subnet1"]
}

# network
#---------------------------------

resource "google_compute_network" "site1_vpc" {
  project      = var.project_id_onprem
  name         = "${local.site1_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

resource "google_compute_subnetwork" "site1_subnets" {
  for_each      = local.site1_subnets
  provider      = google-beta
  project       = var.project_id_onprem
  name          = each.key
  network       = google_compute_network.site1_vpc.id
  region        = each.value.region
  ip_cidr_range = each.value.ip_cidr_range
  secondary_ip_range = each.value.secondary_ip_range == null ? [] : [
    for name, range in each.value.secondary_ip_range :
    { range_name = name, ip_cidr_range = range }
  ]
  purpose = each.value.purpose
  role    = each.value.role
}

# nat
#---------------------------------

module "site1_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v15.0.0"
  for_each              = toset(local.site1_regions)
  project_id            = var.project_id_onprem
  region                = each.key
  name                  = "${local.site1_prefix}${each.key}"
  router_network        = google_compute_network.site1_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

# firewall
#---------------------------------

module "site1_vpc_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall?ref=v15.0.0"
  project_id          = var.project_id_onprem
  network             = google_compute_network.site1_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.site1_prefix}internal" = {
      description          = "allow internal"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = local.netblocks.internal
      targets              = []
      use_service_accounts = false
      rules                = [{ protocol = "all", ports = [] }]
      extra_attributes     = {}
    }
    "${local.site1_prefix}ssh" = {
      description          = "allow ssh"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = ["0.0.0.0/0"]
      targets              = [local.tag_router]
      use_service_accounts = false
      rules                = [{ protocol = "tcp", ports = [22] }]
      extra_attributes     = {}
    }
    "${local.site1_prefix}dns-ingress" = {
      description          = "allow dns egress proxy"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = local.netblocks.dns
      targets              = [local.tag_dns]
      use_service_accounts = false
      rules                = [{ protocol = "all", ports = [] }]
      extra_attributes     = {}
    }
  }
}

# custom dns
#---------------------------------

# unbound config

locals {
  site1_unbound_config = templatefile("../../scripts/startup/unbound/site.sh", {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    FORWARD_ZONES        = local.onprem_forward_zones
  })
}

# unbound instance

resource "google_compute_instance" "site1_dns" {
  project      = var.project_id_onprem
  name         = "${local.site1_prefix}dns"
  machine_type = var.machine_type
  zone         = "${local.site1_region}-b"
  tags         = [local.tag_dns, local.tag_ssh]
  boot_disk {
    initialize_params {
      image = var.image_ubuntu
      type  = var.disk_type
      size  = var.disk_size
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.site1_vpc.self_link
    subnetwork = local.site1_subnet1.self_link
    network_ip = local.site1_ns_addr
  }
  service_account {
    email  = module.site1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.site1_unbound_config
  allow_stopping_for_update = true
}

# cloud dns
#---------------------------------

resource "time_sleep" "site1_dns_forward_to_dns_wait_120s" {
  create_duration = "120s"
  depends_on      = [google_compute_instance.site1_dns]
}

module "site1_dns_forward_to_dns" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id      = var.project_id_onprem
  type            = "forwarding"
  name            = "${local.site1_prefix}to-dns"
  description     = "forward all dns queries to custom resolvers"
  domain          = "."
  client_networks = [google_compute_network.site1_vpc.self_link]
  forwarders = {
    (local.site1_ns_addr) = "private"
    (local.site2_ns_addr) = "private"
  }
  depends_on = [time_sleep.site1_dns_forward_to_dns_wait_120s]
}

# workload
#---------------------------------

# app

resource "google_compute_instance" "site1_vm" {
  project      = var.project_id_onprem
  name         = "${local.site1_prefix}vm"
  machine_type = var.machine_type
  zone         = "${local.site1_region}-b"
  tags         = [local.tag_ssh, local.tag_http]
  boot_disk {
    initialize_params {
      image = var.image_ubuntu
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.site1_vpc.self_link
    subnetwork = local.site1_subnet1.self_link
    network_ip = local.site1_vm_addr
  }
  service_account {
    email  = module.site1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# td client
/*
locals {
  site1_td_client_tpl_create = templatefile("../../scripts/envoy/tpl-create.sh", {
    PROJECT_ID    = var.project_id_onprem
    TEMPLATE_NAME = "${local.site1_prefix}td-client-tpl"
    NETWORK_NAME  = google_compute_network.site1_vpc.name
    REGION        = local.site1_region
    SUBNET_NAME   = local.site1_subnet1.name
    METADATA      = local.td_client_startup
  })
  site1_td_client_tpl_delete = templatefile("../../scripts/envoy/tpl-delete.sh", {
    PROJECT_ID    = var.project_id_onprem
    TEMPLATE_NAME = "${local.site1_prefix}td-client-tpl"
  })
}

resource "null_resource" "site1_td_client_tpl" {
  triggers = {
    create = local.site1_td_client_tpl_create
    delete = local.site1_td_client_tpl_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

data "google_compute_instance_template" "site1_td_client_tpl" {
  depends_on = [null_resource.site1_td_client_tpl]
  project    = var.project_id_onprem
  name       = "${local.site1_prefix}td-client-tpl"
}

resource "google_compute_instance_from_template" "site1_td_client" {
  project = var.project_id_onprem
  name    = "${local.site1_prefix}td-client"
  zone    = "${local.site1_region}-b"
  tags    = [local.tag_ssh, ]
  network_interface {
    subnetwork = local.site1_subnet1.self_link
  }
  service_account {
    email  = module.site1_sa.email
    scopes = ["cloud-platform"]
  }
  source_instance_template = data.google_compute_instance_template.site1_td_client_tpl.name
}*/

# vertex test server
#---------------------------------

# locals {
#   vertex_vm_startup = templatefile("../../scripts/startup/gce.sh", {
#     ENABLE_PROBES = false
#     SCRIPTS = {
#       targets_curl_dns        = local.targets_curl_dns
#       targets_ping_dns       = local.targets_ping_dns
#       targets_pga        = local.targets_pga
#       targets_psc        = local.targets_psc
#       targets_td         = local.targets_td
#       targets_probe      = concat(local.targets_curl_dns, local.targets_pga)
#       targets_bucket     = { ("hub") = module.hub_eu_storage_bucket.name }
#       targets_ai_project = [{ project = var.project_id_hub, region = local.hub_eu_region }, ]
#     }
#     WEB_SERVER = {
#       port                  = 80
#       health_check_path     = local.uhc_config.request_path
#       health_check_response = local.uhc_config.response
#     }
#   })
# }

# module "site1_vertex_vm" {
#   source        = "../../modules/compute-vm"
#   project_id    = var.project_id_onprem
#   name          = "${local.site1_prefix}vertex-vm"
#   zone          = "${local.site1_region}-b"
#   tags          = [local.tag_ssh, ]
#   boot_disk = {
#     image = var.image_ubuntu
#     type  = var.disk_type
#     size  = var.disk_size
#   }
#   network_interfaces = [{
#     network    = google_compute_network.site1_vpc.self_link
#     subnetwork = local.site1_subnet1.self_link
#     addresses = {
#       internal = local.site1_vertex_addr
#       external = null
#     }
#     nat       = false
#     alias_ips = null
#   }]
#   service_account         = module.site1_sa.email
#   service_account_scopes  = ["cloud-platform"]
#   metadata_startup_script = local.vertex_vm_startup
# }

####################################################
# output files
####################################################

locals {
  site1_files = {
    "output/site1-unbound.sh" = local.site1_unbound_config
  }
}

resource "local_file" "site1_files" {
  for_each = local.site1_files
  filename = each.key
  content  = each.value
}
