
locals {
  site2_regions = [local.site2_region, ]
  site2_subnet1 = google_compute_subnetwork.site2_subnets["${local.site2_prefix}subnet1"]
}

# network
#---------------------------------

resource "google_compute_network" "site2_vpc" {
  project      = var.project_id_onprem
  name         = "${local.site2_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

resource "google_compute_subnetwork" "site2_subnets" {
  for_each      = local.site2_subnets
  provider      = google-beta
  project       = var.project_id_onprem
  name          = each.key
  network       = google_compute_network.site2_vpc.id
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

module "site2_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v15.0.0"
  for_each              = toset(local.site2_regions)
  project_id            = var.project_id_onprem
  region                = each.key
  name                  = "${local.site2_prefix}${each.key}"
  router_network        = google_compute_network.site2_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

# firewall
#---------------------------------

module "site2_vpc_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall?ref=v15.0.0"
  project_id          = var.project_id_onprem
  network             = google_compute_network.site2_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.site2_prefix}internal" = {
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
    "${local.site2_prefix}ssh" = {
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
    "${local.site2_prefix}dns-ingress" = {
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
  site2_unbound_config = templatefile("../../scripts/startup/unbound/site.sh", {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    FORWARD_ZONES        = local.onprem_forward_zones
  })
}

# unbound instance

resource "google_compute_instance" "site2_dns" {
  project      = var.project_id_onprem
  name         = "${local.site2_prefix}dns"
  machine_type = var.machine_type
  zone         = "${local.site2_region}-b"
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
    network    = google_compute_network.site2_vpc.self_link
    subnetwork = local.site2_subnet1.self_link
    network_ip = local.site2_ns_addr
  }
  service_account {
    email  = module.site2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.site2_unbound_config
  allow_stopping_for_update = true
}

# cloud dns
#---------------------------------

resource "time_sleep" "site2_dns_forward_to_dns_wait_120s" {
  create_duration = "120s"
  depends_on      = [google_compute_instance.site2_dns]
}

module "site2_dns_forward_to_dns" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id      = var.project_id_onprem
  type            = "forwarding"
  name            = "${local.site2_prefix}to-dns"
  description     = "forward all dns queries to custom resolvers"
  domain          = "."
  client_networks = [google_compute_network.site2_vpc.self_link]
  forwarders = {
    (local.site2_ns_addr) = "private"
    (local.site2_ns_addr) = "private"
  }
  depends_on = [time_sleep.site2_dns_forward_to_dns_wait_120s]
}

# workload
#---------------------------------

# app

resource "google_compute_instance" "site2_vm" {
  project      = var.project_id_onprem
  name         = "${local.site2_prefix}vm"
  machine_type = var.machine_type
  zone         = "${local.site2_region}-b"
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
    network    = google_compute_network.site2_vpc.self_link
    subnetwork = local.site2_subnet1.self_link
    network_ip = local.site2_vm_addr
  }
  service_account {
    email  = module.site2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# td client
/*
locals {
  site2_td_client_tpl_create = templatefile("../../scripts/envoy/tpl-create.sh", {
    PROJECT_ID    = var.project_id_onprem
    TEMPLATE_NAME = "${local.site2_prefix}td-client-tpl"
    NETWORK_NAME  = google_compute_network.site2_vpc.name
    REGION        = local.site2_region
    SUBNET_NAME   = local.site2_subnet1.name
    METADATA      = local.td_client_startup
  })
  site2_td_client_tpl_delete = templatefile("../../scripts/envoy/tpl-delete.sh", {
    PROJECT_ID    = var.project_id_onprem
    TEMPLATE_NAME = "${local.site2_prefix}td-client-tpl"
  })
}

resource "null_resource" "site2_td_client_tpl" {
  triggers = {
    create = local.site2_td_client_tpl_create
    delete = local.site2_td_client_tpl_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

data "google_compute_instance_template" "site2_td_client_tpl" {
  depends_on = [null_resource.site2_td_client_tpl]
  project    = var.project_id_onprem
  name       = "${local.site2_prefix}td-client-tpl"
}

resource "google_compute_instance_from_template" "site2_td_client" {
  project = var.project_id_onprem
  name    = "${local.site2_prefix}td-client"
  zone    = "${local.site2_region}-b"
  tags    = [local.tag_ssh, ]
  network_interface {
    subnetwork = local.site2_subnet1.self_link
  }
  service_account {
    email  = module.site2_sa.email
    scopes = ["cloud-platform"]
  }
  source_instance_template = data.google_compute_instance_template.site2_td_client_tpl.name
}*/

####################################################
# output files
####################################################

locals {
  site2_files = {
    "output/site2-unbound.sh" = local.site2_unbound_config
  }
}

resource "local_file" "site2_files" {
  for_each = local.site2_files
  filename = each.key
  content  = each.value
}
