
locals {
  spoke1_subnet_names = keys(local.spoke1_subnets)
  spoke1_regions      = [local.spoke1_eu_region, local.spoke1_us_region, ]
  spoke1_eu_subnet1   = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"]
  spoke1_eu_subnet2   = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-subnet2"]
  spoke1_eu_subnet3   = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-subnet3"]
  spoke1_us_subnet1   = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}us-subnet1"]
  spoke1_us_subnet2   = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}us-subnet2"]
  spoke1_us_subnet3   = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}us-subnet3"]

  spoke1_eu_psc_producer_nat_subnet1 = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-psc-producer-nat-subnet1"]
  spoke1_us_psc_producer_nat_subnet1 = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}us-psc-producer-nat-subnet1"]
}

# network
#---------------------------------

resource "google_compute_network" "spoke1_vpc" {
  project      = var.project_id_host
  name         = "${local.spoke1_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

resource "google_compute_subnetwork" "spoke1_subnets" {
  for_each      = local.spoke1_subnets
  provider      = google-beta
  project       = var.project_id_host
  name          = each.key
  network       = google_compute_network.spoke1_vpc.id
  region        = each.value.region
  ip_cidr_range = each.value.ip_cidr_range
  secondary_ip_range = each.value.secondary_ip_range == null ? [] : [
    for name, range in each.value.secondary_ip_range :
    { range_name = name, ip_cidr_range = range }
  ]
  purpose = each.value.purpose
  role    = each.value.role
}

# addresses
#---------------------------------

resource "google_compute_global_address" "spoke1_eu_psa_range1" {
  project       = var.project_id_host
  name          = "${local.spoke1_prefix}spoke1-eu-psa-range1"
  network       = google_compute_network.spoke1_vpc.self_link
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", local.spoke1_eu_psa_range1).0
  prefix_length = split("/", local.spoke1_eu_psa_range1).1
}

resource "google_compute_global_address" "spoke1_eu_psa_range2" {
  project       = var.project_id_host
  name          = "${local.spoke1_prefix}spoke1-eu-psa-range2"
  network       = google_compute_network.spoke1_vpc.self_link
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", local.spoke1_eu_psa_range2).0
  prefix_length = split("/", local.spoke1_eu_psa_range2).1
}

# service networking connection
#---------------------------------

resource "google_service_networking_connection" "spoke1_eu_psa_ranges" {
  provider = google-beta
  network  = google_compute_network.spoke1_vpc.self_link
  service  = "servicenetworking.googleapis.com"

  reserved_peering_ranges = [
    google_compute_global_address.spoke1_eu_psa_range1.name,
    google_compute_global_address.spoke1_eu_psa_range2.name
  ]
}

# nat
#---------------------------------

module "spoke1_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v15.0.0"
  for_each              = toset(local.spoke1_regions)
  project_id            = var.project_id_host
  region                = each.key
  name                  = "${local.spoke1_prefix}${each.key}"
  router_network        = google_compute_network.spoke1_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

# firewall
#---------------------------------

module "spoke1_vpc_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall?ref=v15.0.0"
  project_id          = var.project_id_host
  network             = google_compute_network.spoke1_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.spoke1_prefix}internal" = {
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
    "${local.spoke1_prefix}gfe" = {
      description          = "allow gfe"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = local.netblocks.gfe
      targets              = [local.tag_gfe]
      use_service_accounts = false
      rules                = [{ protocol = "all", ports = [] }]
      extra_attributes     = {}
    }
    "${local.spoke1_prefix}ssh" = {
      description          = "allow ssh"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = ["0.0.0.0/0"]
      targets              = []
      use_service_accounts = false
      rules                = [{ protocol = "tcp", ports = [22] }]
      extra_attributes     = {}
    }
  }
}

# shared vpc
#---------------------------------

resource "google_compute_shared_vpc_host_project" "central" {
  project = var.project_id_host
}

resource "google_compute_shared_vpc_service_project" "spoke1" {
  host_project    = google_compute_shared_vpc_host_project.central.project
  service_project = var.project_id_spoke1
  depends_on      = [google_compute_shared_vpc_host_project.central]
}

locals {
  remove_service_project_spoke1 = <<EOT
  gcloud compute shared-vpc associated-projects remove ${var.project_id_spoke1} --host-project=${var.project_id_host}
EOT
}

resource "null_resource" "remove_service_project_spoke1" {
  depends_on = [google_compute_shared_vpc_service_project.spoke1]
  triggers = {
    create = ":"
    delete = local.remove_service_project_spoke1
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# project constraints
#---------------------------------

resource "google_project_organization_policy" "spoke1_subnets_for_spoke1_only" {
  project    = var.project_id_spoke1
  constraint = "compute.restrictSharedVpcSubnetworks"
  list_policy {
    allow {
      values = [
        local.spoke1_eu_subnet1.id,
        local.spoke1_eu_subnet2.id,
        local.spoke1_eu_subnet3.id,
        local.spoke1_us_subnet1.id,
        local.spoke1_us_subnet2.id,
        local.spoke1_us_subnet3.id,
      ]
    }
    suggested_value = "spoke1-project-x has access to only spoke1 subnets in central-project-x"
  }
}

# psc/api
#---------------------------------

# vip

resource "google_compute_global_address" "spoke1_psc_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_host
  name         = local.spoke1_psc_api_fr_name
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.spoke1_vpc.self_link
  address      = local.spoke1_psc_api_fr_addr
}

# fr

resource "google_compute_global_forwarding_rule" "spoke1_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_host
  name                  = local.spoke1_psc_api_fr_name
  target                = local.spoke1_psc_api_fr_target
  network               = google_compute_network.spoke1_vpc.self_link
  ip_address            = google_compute_global_address.spoke1_psc_api_fr_addr.id
  load_balancing_scheme = ""
}
