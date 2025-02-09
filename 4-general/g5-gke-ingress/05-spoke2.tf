
locals {
  spoke2_vpc_tags = {
    "${local.spoke2_prefix}vpc-dns" = { value = "dns", description = "custom dns servers" }
    "${local.spoke2_prefix}vpc-gfe" = { value = "gfe", description = "load balancer backends" }
    "${local.spoke2_prefix}vpc-nva" = { value = "nva", description = "nva appliances" }
  }
  spoke2_vpc_tags_dns = google_tags_tag_value.spoke2_vpc_tags["${local.spoke2_prefix}vpc-dns"]
  spoke2_vpc_tags_gfe = google_tags_tag_value.spoke2_vpc_tags["${local.spoke2_prefix}vpc-gfe"]
  spoke2_vpc_tags_nva = google_tags_tag_value.spoke2_vpc_tags["${local.spoke2_prefix}vpc-nva"]

  spoke2_vpc_ipv6_cidr = module.spoke2_vpc.internal_ipv6_range
  # spoke2_eu_vm_main_ipv6 = module.spoke2_eu_vm.internal_ipv6
  # spoke2_us_vm_main_ipv6 = module.spoke2_us_vm.internal_ipv6
}

####################################################
# network
####################################################

module "spoke2_vpc" {
  # source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v34.1.0"
  source     = "../../modules/net-vpc"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}vpc"

  subnets             = local.spoke2_subnets_list
  subnets_private_nat = local.spoke2_subnets_private_nat_list
  subnets_proxy_only  = local.spoke2_subnets_proxy_only_list
  subnets_psc         = local.spoke2_subnets_psc_list

  ipv6_config = {
    enable_ula_internal = true
  }

  # psa_configs = [{
  #   ranges = {
  #     "spoke2-us-psa-range1" = local.spoke2_us_psa_range1
  #     "spoke2-us-psa-range2" = local.spoke2_us_psa_range2
  #   }
  #   export_routes  = true
  #   import_routes  = true
  #   peered_domains = ["gcp.example.com."]
  # }]
}

####################################################
# secure tags
####################################################

# keys

resource "google_tags_tag_key" "spoke2_vpc" {
  for_each    = local.spoke2_vpc_tags
  parent      = "projects/${var.project_id_spoke2}"
  short_name  = each.key
  description = each.value.description
  purpose     = "GCE_FIREWALL"
  purpose_data = {
    network = "${var.project_id_spoke2}/${module.spoke2_vpc.name}"
  }
}

# values

resource "google_tags_tag_value" "spoke2_vpc_tags" {
  for_each    = local.spoke2_vpc_tags
  parent      = google_tags_tag_key.spoke2_vpc[each.key].id
  short_name  = each.value.value
  description = each.value.description
}

####################################################
# addresses
####################################################

resource "google_compute_address" "spoke2_eu_main_addresses" {
  for_each     = local.spoke2_eu_main_addresses
  project      = var.project_id_spoke2
  name         = each.key
  subnetwork   = module.spoke2_vpc.subnet_ids["${local.spoke2_eu_region}/eu-main"]
  address_type = "INTERNAL"
  address      = each.value.ipv4
  region       = local.spoke2_eu_region
}

resource "google_compute_address" "spoke2_us_main_addresses" {
  for_each     = local.spoke2_us_main_addresses
  project      = var.project_id_spoke2
  name         = each.key
  subnetwork   = module.spoke2_vpc.subnet_ids["${local.spoke2_us_region}/us-main"]
  address_type = "INTERNAL"
  address      = each.value.ipv4
  region       = local.spoke2_us_region
}

####################################################
# service networking connection
####################################################

# resource "google_service_networking_connection" "spoke2_us_psa_ranges" {
#   provider = google-beta
#   network  = module.spoke2_vpc.self_link
#   service  = "servicenetworking.googleapis.com"

#   reserved_peering_ranges = [
#     google_compute_global_address.spoke2_us_psa_range1.name,
#     google_compute_global_address.spoke2_us_psa_range2.name
#   ]
# }

####################################################
# nat
####################################################

module "spoke2_nat_eu" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v34.1.0"
  project_id     = var.project_id_spoke2
  region         = local.spoke2_eu_region
  name           = "${local.spoke2_prefix}eu-nat"
  router_network = module.spoke2_vpc.self_link
  router_create  = true

  config_source_subnetworks = {
    primary_ranges_only = true
  }
}

module "spoke2_nat_us" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v34.1.0"
  project_id     = var.project_id_spoke2
  region         = local.spoke2_us_region
  name           = "${local.spoke2_prefix}us-nat"
  router_network = module.spoke2_vpc.self_link
  router_create  = true

  config_source_subnetworks = {
    primary_ranges_only = true
  }
}

####################################################
# firewall
####################################################

# firewall rules
# adding vpc firewall rule to temporarily resolve the issue with firewall policy
# not allowing health check for external passthrough load balancer

# vpc

module "spoke2_vpc_firewall" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall?ref=v34.1.0"
  project_id = var.project_id_spoke2
  network    = module.spoke2_vpc.name

  egress_rules = {
    "${local.spoke2_prefix}allow-egress-all" = {
      priority           = 1000
      deny               = false
      description        = "allow egress"
      destination_ranges = ["0.0.0.0/0", ]
      rules              = [{ protocol = "all", ports = [] }]
    }
    # ipv6
    "${local.spoke2_prefix}allow-egress-smtp-ipv6" = {
      priority           = 901
      description        = "block smtp"
      destination_ranges = ["::/0", ]
      rules              = [{ protocol = "tcp", ports = [25, ] }]
    }
    "${local.spoke2_prefix}allow-egress-all-ipv6" = {
      priority           = 1001
      deny               = false
      description        = "allow egress"
      destination_ranges = ["::/0", ]
      rules              = [{ protocol = "all", ports = [] }]
    }
  }
  ingress_rules = {
    # ipv4
    "${local.spoke2_prefix}allow-ingress-internal" = {
      priority      = 1000
      description   = "allow internal"
      source_ranges = local.netblocks.internal
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.spoke2_prefix}allow-ingress-dns" = {
      priority      = 1100
      description   = "allow dns"
      source_ranges = local.netblocks.dns
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.spoke2_prefix}allow-ingress-ssh" = {
      priority       = 1200
      description    = "allow ingress ssh"
      source_ranges  = ["0.0.0.0/0"]
      targets        = [local.tag_router]
      rules          = [{ protocol = "tcp", ports = [22] }]
      enable_logging = {}
    }
    "${local.spoke2_prefix}allow-ingress-iap" = {
      priority       = 1300
      description    = "allow ingress iap"
      source_ranges  = local.netblocks.iap
      targets        = [local.tag_router]
      rules          = [{ protocol = "all", ports = [] }]
      enable_logging = {}
    }
    "${local.spoke2_prefix}allow-ingress-dns-proxy" = {
      priority      = 1400
      description   = "allow dns egress proxy"
      source_ranges = local.netblocks.dns
      targets       = [local.tag_dns]
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.spoke2_prefix}allow-ingress-gfe" = {
      priority      = 1000
      description   = "allow internal"
      source_ranges = local.netblocks.gfe
      rules         = [{ protocol = "all", ports = [] }]
    }
    # ipv6
    "${local.spoke2_prefix}allow-ingress-internal-ipv6" = {
      priority      = 1000
      description   = "allow internal"
      source_ranges = local.netblocks_ipv6.internal
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.spoke2_prefix}allow-ingress-ssh-ipv6" = {
      priority       = 1200
      description    = "allow ingress ssh"
      source_ranges  = ["::/0"]
      targets        = [local.tag_router]
      rules          = [{ protocol = "tcp", ports = [22] }]
      enable_logging = {}
    }
  }
}

####################################################
# psc api
####################################################

# address

resource "google_compute_global_address" "spoke2_psc_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_spoke2
  name         = local.spoke2_psc_api_fr_name
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = module.spoke2_vpc.self_link
  address      = local.spoke2_psc_api_fr_addr
}

# forwarding rule

resource "google_compute_global_forwarding_rule" "spoke2_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_spoke2
  name                  = local.spoke2_psc_api_fr_name
  target                = local.spoke2_psc_api_fr_target
  network               = module.spoke2_vpc.self_link
  ip_address            = google_compute_global_address.spoke2_psc_api_fr_addr.id
  load_balancing_scheme = ""
}

####################################################
# dns policy
####################################################

resource "google_dns_policy" "spoke2_dns_policy" {
  provider                  = google-beta
  project                   = var.project_id_spoke2
  name                      = "${local.spoke2_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = module.spoke2_vpc.self_link }
}

####################################################
# dns response policy
####################################################

# rules - local

locals {
  spoke2_dns_rp_rules = {
    # drp-rule-eu-psc-be = { dns_name = "${local.spoke2_eu_psc_be_run_dns}.", local_data = { A = { rrdatas = [local.spoke2_eu_alb_addr] } } }
    # drp-rule-us-psc-be = { dns_name = "${local.spoke2_us_psc_be_run_dns}.", local_data = { A = { rrdatas = [local.spoke2_us_alb_addr] } } }
    drp-rule-runapp        = { dns_name = "*.run.app.", local_data = { A = { rrdatas = [local.spoke2_psc_api_fr_addr] } } }
    drp-rule-gcr           = { dns_name = "*.gcr.io.", local_data = { A = { rrdatas = [local.spoke2_psc_api_fr_addr] } } }
    drp-rule-apis          = { dns_name = "*.googleapis.com.", local_data = { A = { rrdatas = [local.spoke2_psc_api_fr_addr] } } }
    drp-rule-bypass-www    = { dns_name = "www.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-ouath2 = { dns_name = "oauth2.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-psc    = { dns_name = "*.p.googleapis.com.", behavior = "bypassResponsePolicy" }
  }
}

# policy

module "spoke2_dns_response_policy" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns-response-policy?ref=v34.1.0"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}drp"
  rules      = local.spoke2_dns_rp_rules
  networks = {
    spoke2 = module.spoke2_vpc.self_link
  }
}

####################################################
# cloud dns
####################################################

# psc zone

module "spoke2_dns_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v34.1.0"
  project_id  = var.project_id_spoke2
  name        = "${local.spoke2_prefix}psc"
  description = "psc"
  zone_config = {
    domain = "${local.spoke2_psc_api_fr_name}.p.googleapis.com."
    private = {
      client_networks = [
        module.hub_vpc.self_link,
        # module.spoke1_vpc.self_link,
        module.spoke2_vpc.self_link,
      ]
    }
  }
  recordsets = {
    "A " = { ttl = 300, records = [local.spoke2_psc_api_fr_addr] }
  }
}

# local zone

module "spoke2_dns_private_zone" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v34.1.0"
  project_id  = var.project_id_spoke2
  name        = "${local.spoke2_prefix}private"
  description = "local data"
  zone_config = {
    domain = "${local.spoke2_dns_zone}."
    private = {
      client_networks = [
        module.hub_vpc.self_link,
        # module.spoke1_vpc.self_link,
        module.spoke2_vpc.self_link,
      ]
    }
  }
  recordsets = {
    "A ${local.spoke2_us_vm_dns_prefix}" = { ttl = 300, records = [local.spoke2_us_vm_addr] },
    "A ${local.spoke2_eu_vm_dns_prefix}" = { ttl = 300, records = [local.spoke2_eu_vm_addr] },
    # "AAAA ${local.spoke2_us_vm_dns_prefix}" = { ttl = 300, records = [local.spoke2_us_vm_main_ipv6] },
    # "AAAA ${local.spoke2_eu_vm_dns_prefix}" = { ttl = 300, records = [local.spoke2_eu_vm_main_ipv6] },
  }
}

# onprem zone

module "spoke2_dns_peering_to_hub_to_onprem" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v34.1.0"
  project_id  = var.project_id_spoke2
  name        = "${local.spoke2_prefix}to-hub-to-onprem"
  description = "peering to hub for onprem"
  zone_config = {
    domain = "${local.onprem_domain}."
    peering = {
      client_networks = [module.spoke2_vpc.self_link]
      peer_network    = module.hub_vpc.self_link
    }
  }
}

# reverse lookup zone (self-managed reverse lookup zones)

module "spoke2_reverse_zone" {
  source      = "../../modules/dns"
  project_id  = var.project_id_spoke2
  name        = "${local.spoke2_prefix}reverse-zone"
  description = "spoke2 reverse zone"
  zone_config = {
    domain = local.spoke2_reverse_zone
    private = {
      client_networks = [
        module.hub_vpc.self_link,
        # module.spoke1_vpc.self_link,
        module.spoke2_vpc.self_link,
      ]
    }
  }
  recordsets = {
    "PTR ${local.spoke2_us_ilb_reverse_suffix}" = { ttl = 300, records = ["${local.spoke2_us_ilb_fqdn}."] },
    "PTR ${local.spoke2_us_alb_reverse_suffix}" = { ttl = 300, records = ["${local.spoke2_us_alb_fqdn}."] },
  }
}

####################################################
# workload
####################################################

# eu

module "spoke2_eu_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}eu-vm"
  zone       = "${local.spoke2_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.spoke2_vpc_tags_gfe.parent) = local.spoke2_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.spoke2_vpc.self_link
    subnetwork = module.spoke2_vpc.subnet_self_links["${local.spoke2_eu_region}/eu-main"]
    addresses  = { internal = local.spoke2_eu_vm_addr }
  }]
  service_account = {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}

# us

module "spoke2_us_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}us-vm"
  zone       = "${local.spoke2_us_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.spoke2_vpc_tags_gfe.parent) = local.spoke2_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.spoke2_vpc.self_link
    subnetwork = module.spoke2_vpc.subnet_self_links["${local.spoke2_us_region}/us-main"]
    addresses  = { internal = local.spoke2_us_vm_addr }
  }]
  service_account = {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}

####################################################
# output files
####################################################

locals {
  spoke2_files = {}
}

resource "local_file" "spoke2_files" {
  for_each = local.spoke2_files
  filename = each.key
  content  = each.value
}
