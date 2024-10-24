
locals {
  spoke1_vpc_tags = {
    "${local.spoke1_prefix}vpc-dns" = { value = "dns", description = "custom dns servers" }
    "${local.spoke1_prefix}vpc-gfe" = { value = "gfe", description = "load balancer backends" }
    "${local.spoke1_prefix}vpc-nva" = { value = "nva", description = "nva appliances" }
  }
  spoke1_vpc_tags_dns = google_tags_tag_value.spoke1_vpc_tags["${local.spoke1_prefix}vpc-dns"]
  spoke1_vpc_tags_gfe = google_tags_tag_value.spoke1_vpc_tags["${local.spoke1_prefix}vpc-gfe"]
  spoke1_vpc_tags_nva = google_tags_tag_value.spoke1_vpc_tags["${local.spoke1_prefix}vpc-nva"]

  spoke1_vpc_ipv6_cidr = module.spoke1_vpc.internal_ipv6_range
}

# network
#---------------------------------

module "spoke1_vpc" {
  # source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v33.0.0"
  source     = "../../modules/net-vpc"
  project_id = var.project_id_host
  name       = "${local.spoke1_prefix}vpc"

  subnets             = local.spoke1_subnets_list
  subnets_private_nat = local.spoke1_subnets_private_nat_list
  subnets_proxy_only  = local.spoke1_subnets_proxy_only_list
  subnets_psc         = local.spoke1_subnets_psc_list

  ipv6_config = {
    enable_ula_internal = true
  }

  shared_vpc_host = true
  shared_vpc_service_projects = [
    var.project_id_spoke1
  ]

  psa_configs = [{
    ranges = {
      "spoke1-eu-psa-range1" = local.spoke1_eu_psa_range1
      "spoke1-eu-psa-range2" = local.spoke1_eu_psa_range2
    }
    export_routes  = true
    import_routes  = true
    peered_domains = ["gcp.example.com."]
  }]
}

# secure tags
#---------------------------------

# keys

resource "google_tags_tag_key" "spoke1_vpc" {
  for_each    = local.spoke1_vpc_tags
  parent      = "projects/${var.project_id_spoke1}"
  short_name  = each.key
  description = each.value.description
  purpose     = "GCE_FIREWALL"
  purpose_data = {
    network = "${var.project_id_host}/${module.spoke1_vpc.name}"
  }
}

# values

resource "google_tags_tag_value" "spoke1_vpc_tags" {
  for_each    = local.spoke1_vpc_tags
  parent      = google_tags_tag_key.spoke1_vpc[each.key].id
  short_name  = each.value.value
  description = each.value.description
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

# policy

module "spoke1_vpc_fw_policy" {
  source    = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-firewall-policy?ref=v33.0.0"
  name      = "${local.spoke1_prefix}vpc-fw-policy"
  parent_id = var.project_id_host
  region    = "global"
  attachments = {
    spoke1-vpc = module.spoke1_vpc.self_link
  }
  egress_rules = {
    # ipv4
    smtp = {
      priority = 900
      match = {
        destination_ranges = ["0.0.0.0/0"]
        layer4_configs     = [{ protocol = "tcp", ports = ["25"] }]
      }
    }
    smtp-6 = {
      priority = 901
      match = {
        destination_ranges = ["0::/0"]
        layer4_configs     = [{ protocol = "tcp", ports = ["25"] }]
      }
    }
  }
  ingress_rules = {
    # ipv4
    internal = {
      priority = 1000
      match = {
        source_ranges  = local.netblocks.internal
        layer4_configs = [{ protocol = "all" }]
      }
    }
    dns = {
      priority    = 1100
      target_tags = [local.spoke1_vpc_tags_dns.id, local.spoke1_vpc_tags_nva.id, ]
      match = {
        source_ranges  = local.netblocks.dns
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
    }
    ssh = {
      priority       = 1200
      target_tags    = [local.spoke1_vpc_tags_nva.id, ]
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
      priority    = 1400
      target_tags = [local.spoke1_vpc_tags_nva.id, ]
      match = {
        source_ranges = ["0.0.0.0/0", ]
        layer4_configs = [
          { protocol = "udp", ports = ["500", "4500", ] },
          { protocol = "esp", ports = [] }
        ]
      }
    }
    gfe = {
      priority    = 1500
      target_tags = [local.spoke1_vpc_tags_gfe.id, ]
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
      target_tags    = [local.spoke1_vpc_tags_nva.id, ]
      enable_logging = true
      match = {
        source_ranges  = ["0::/0", ]
        layer4_configs = [{ protocol = "tcp", ports = ["22"] }]
      }
    }
    vpn-6 = {
      priority    = 1401
      target_tags = [local.spoke1_vpc_tags_nva.id, ]
      match = {
        source_ranges = ["0::/0", ]
        layer4_configs = [
          { protocol = "udp", ports = ["500", "4500", ] },
          { protocol = "esp", ports = [] }
        ]
      }
    }
    gfe-6 = {
      priority    = 1501
      target_tags = [local.spoke1_vpc_tags_gfe.id, ]
      match = {
        source_ranges  = local.netblocks_ipv6.gfe
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
        module.spoke1_vpc.subnets_psc["${local.spoke1_eu_region}/eu-psc-ilb4-nat"].id,
        module.spoke1_vpc.subnets_psc["${local.spoke1_us_region}/us-psc-ilb4-nat"].id,
        module.spoke1_vpc.subnets_proxy_only["${local.spoke1_eu_region}/eu-reg-proxy"].id,
        module.spoke1_vpc.subnets_proxy_only["${local.spoke1_us_region}/us-reg-proxy"].id,
      ]
    }
    suggested_value = "prj-spoke1-x has access to only spoke1 subnets in prj-hub-x"
  }
}

# psc/api
#---------------------------------

# address

resource "google_compute_global_address" "spoke1_psc_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_host
  name         = local.spoke1_psc_api_fr_name
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = module.spoke1_vpc.self_link
  address      = local.spoke1_psc_api_fr_addr
}

# forwarding rule

resource "google_compute_global_forwarding_rule" "spoke1_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_host
  name                  = local.spoke1_psc_api_fr_name
  target                = local.spoke1_psc_api_fr_target
  network               = module.spoke1_vpc.self_link
  ip_address            = google_compute_global_address.spoke1_psc_api_fr_addr.id
  load_balancing_scheme = ""
}
