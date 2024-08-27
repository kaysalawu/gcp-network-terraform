
# network
#---------------------------------

module "spoke1_vpc" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v33.0.0"
  project_id = var.project_id_host
  name       = "${local.spoke1_prefix}vpc"

  subnets             = local.spoke1_subnets_list
  subnets_private_nat = local.spoke1_subnets_private_nat_list
  subnets_proxy_only  = local.spoke1_subnets_proxy_only_list
  subnets_psc         = local.spoke1_subnets_psc_list

  shared_vpc_host = true
  shared_vpc_service_projects = [
    var.project_id_spoke1
  ]

  # psa_configs = [{
  #   ranges = {
  #     "spoke1-eu-psa-range1" = local.spoke1_eu_psa_range1
  #     "spoke1-eu-psa-range2" = local.spoke1_eu_psa_range2
  #   }
  #   export_routes  = true
  #   import_routes  = true
  #   peered_domains = ["gcp.example.com."]
  # }]
}

# addresses
#---------------------------------

resource "google_compute_address" "spoke1_eu_main_addresses" {
  for_each     = local.spoke1_eu_main_addresses
  project      = var.project_id_spoke1
  name         = each.key
  subnetwork   = module.spoke1_vpc.subnet_ids["${local.spoke1_eu_region}/eu-main"]
  address_type = "INTERNAL"
  address      = each.value.ipv4
  region       = local.spoke1_eu_region
}

resource "google_compute_address" "spoke1_us_main_addresses" {
  for_each     = local.spoke1_us_main_addresses
  project      = var.project_id_spoke1
  name         = each.key
  subnetwork   = module.spoke1_vpc.subnet_ids["${local.spoke1_us_region}/us-main"]
  address_type = "INTERNAL"
  address      = each.value.ipv4
  region       = local.spoke1_us_region
}


# service networking connection
#---------------------------------

# resource "google_service_networking_connection" "spoke1_eu_psa_ranges" {
#   provider = google-beta
#   network  = google_compute_network.spoke1_vpc.self_link
#   service  = "servicenetworking.googleapis.com"

#   reserved_peering_ranges = [
#     google_compute_global_address.spoke1_eu_psa_range1.name,
#     google_compute_global_address.spoke1_eu_psa_range2.name
#   ]
# }

# nat
#---------------------------------

module "spoke1_nat_eu" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v33.0.0"
  project_id     = var.project_id_host
  region         = local.spoke1_eu_region
  name           = "${local.spoke1_prefix}eu-nat"
  router_network = module.spoke1_vpc.self_link
  router_create  = true

  config_source_subnetworks = {
    primary_ranges_only = true
  }
}

module "spoke1_nat_us" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v33.0.0"
  project_id     = var.project_id_host
  region         = local.spoke1_us_region
  name           = "${local.spoke1_prefix}us-nat"
  router_network = module.spoke1_vpc.self_link
  router_create  = true

  config_source_subnetworks = {
    primary_ranges_only = true
  }
}

# firewall
#---------------------------------

module "spoke11_vpc_fw_policy" {
  source    = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-firewall-policy?ref=v33.0.0"
  name      = "${local.spoke1_prefix}vpc-fw-policy"
  parent_id = var.project_id_host
  region    = "global"
  attachments = {
    spoke1-vpc = module.spoke1_vpc.self_link
  }
  egress_rules = {
    smtp = {
      priority = 900
      match = {
        destination_ranges = ["0.0.0.0/0"]
        layer4_configs     = [{ protocol = "tcp", ports = ["25"] }]
      }
    }
  }
  ingress_rules = {
    internal = {
      priority = 1000
      match = {
        source_ranges  = local.netblocks.internal
        layer4_configs = [{ protocol = "all" }]
      }
    }
    ssh = {
      priority       = 1001
      enable_logging = true
      match = {
        source_ranges  = ["0.0.0.0/0", ]
        layer4_configs = [{ protocol = "tcp", ports = ["22"] }]
      }
    }
    dns = {
      priority = 1003
      match = {
        source_ranges  = local.netblocks.dns
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
    }
    gfe = {
      priority = 1004
      match = {
        source_ranges  = local.netblocks.gfe
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
    }
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
        module.spoke1_vpc.subnet_ids["${local.spoke1_eu_region}/eu-main"],
        module.spoke1_vpc.subnet_ids["${local.spoke1_eu_region}/eu-gke"],
        module.spoke1_vpc.subnet_ids["${local.spoke1_us_region}/us-main"],
        module.spoke1_vpc.subnet_ids["${local.spoke1_us_region}/us-gke"],
        module.spoke1_vpc.subnets_psc["${local.spoke1_eu_region}/eu-psc-nat"].id,
        module.spoke1_vpc.subnets_psc["${local.spoke1_us_region}/us-psc-nat"].id,
        module.spoke1_vpc.subnets_proxy_only["${local.spoke1_eu_region}/eu-reg-proxy"].id,
        module.spoke1_vpc.subnets_proxy_only["${local.spoke1_us_region}/us-reg-proxy"].id,
      ]
    }
    suggested_value = "prj-spoke1-x has access to only spoke1 subnets in prj-central-x"
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
  network      = module.spoke1_vpc.self_link
  address      = local.spoke1_psc_api_fr_addr
}

# fr

resource "google_compute_global_forwarding_rule" "spoke1_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_host
  name                  = local.spoke1_psc_api_fr_name
  target                = local.spoke1_psc_api_fr_target
  network               = module.spoke1_vpc.self_link
  ip_address            = google_compute_global_address.spoke1_psc_api_fr_addr.id
  load_balancing_scheme = ""
}
