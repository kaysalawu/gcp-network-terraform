
locals {
  hub_vpc_name = "${local.hub_prefix}vpc"
  hub_secure_tags = {
    "egress-internet"  = { value = "self", description = "allow internet egress traffic" }
    "egress-private"   = { value = "self", description = "allow private egress traffic" }
    "ingress-internet" = { value = "self", description = "allow internet egress traffic" }
    "ingress-private"  = { value = "self", description = "allow private ingress traffic" }
  }
  hub_secure_tags_egress_internet  = google_tags_tag_value.hub_secure_tags["egress-internet"]
  hub_secure_tags_egress_private   = google_tags_tag_value.hub_secure_tags["egress-private"]
  hub_secure_tags_ingress_internet = google_tags_tag_value.hub_secure_tags["ingress-internet"]
  hub_secure_tags_ingress_private  = google_tags_tag_value.hub_secure_tags["ingress-private"]
}

####################################################
# network
####################################################

module "hub_vpc" {
  source     = "../../modules/net-vpc"
  project_id = var.project_id_hub
  name       = local.hub_vpc_name

  subnets             = local.hub_subnets_list
  subnets_private_nat = local.hub_subnets_private_nat_list
  subnets_proxy_only  = local.hub_subnets_proxy_only_list
  subnets_psc         = local.hub_subnets_psc_list

  ipv6_config = {
    enable_ula_internal = true
  }

  psa_configs = [{
    ranges = {
      "hub-eu-psa-range1" = local.hub_eu_psa_range1
      "hub-eu-psa-range2" = local.hub_eu_psa_range2
    }
    export_routes  = true
    import_routes  = true
    peered_domains = ["${local.hub_dns_zone}."]
  }]
}

####################################################
# secure tags
####################################################

# keys

resource "google_tags_tag_key" "hub_secure_tags" {
  for_each    = local.hub_secure_tags
  parent      = "projects/${var.project_id_hub}"
  short_name  = each.key
  description = each.value.description
  purpose     = "GCE_FIREWALL"
  purpose_data = {
    network = "${var.project_id_hub}/${module.hub_vpc.name}"
  }
}

# values

resource "google_tags_tag_value" "hub_secure_tags" {
  for_each    = local.hub_secure_tags
  parent      = google_tags_tag_key.hub_secure_tags[each.key].id
  short_name  = each.value.value
  description = each.value.description
}

####################################################
# addresses
####################################################

resource "google_compute_address" "hub_eu_main_addresses" {
  for_each     = local.hub_eu_main_addresses
  project      = var.project_id_hub
  name         = each.key
  subnetwork   = module.hub_vpc.subnet_ids["${local.hub_eu_region}/eu-main"]
  address_type = "INTERNAL"
  address      = each.value.ipv4
  region       = local.hub_eu_region
}

resource "google_compute_address" "hub_us_main_addresses" {
  for_each     = local.hub_us_main_addresses
  project      = var.project_id_hub
  name         = each.key
  subnetwork   = module.hub_vpc.subnet_ids["${local.hub_us_region}/us-main"]
  address_type = "INTERNAL"
  address      = each.value.ipv4
  region       = local.hub_us_region
}

####################################################
# service networking connection
####################################################

# vpc-sc config

# resource "google_service_networking_vpc_service_controls" "hub" {
#   provider   = google-beta
#   project    = var.project_id_hub
#   network    = google_compute_network.hub_vpc.name
#   service    = google_service_networking_connection.hub_eu_psa_ranges.service
#   enabled    = true
#   depends_on = [google_compute_network_peering_routes_config.hub_eu_psa_ranges]
# }

####################################################
# nat
####################################################

module "hub_nat_eu" {
  source         = "../../modules/net-cloudnat"
  project_id     = var.project_id_hub
  region         = local.hub_eu_region
  name           = "${local.hub_prefix}eu-nat"
  router_network = module.hub_vpc.self_link
  router_create  = true

  config_source_subnetworks = {
    primary_ranges_only = true
  }
}

module "hub_nat_us" {
  source         = "../../modules/net-cloudnat"
  project_id     = var.project_id_hub
  region         = local.hub_us_region
  name           = "${local.hub_prefix}us-nat"
  router_network = module.hub_vpc.self_link
  router_create  = true

  config_source_subnetworks = {
    primary_ranges_only = true
  }
}

####################################################
# firewall
####################################################

# policy

module "hub_vpc_fw_policy_rules" {
  source            = "../../modules/firewall-policy-rules"
  vpc_name          = local.hub_vpc_name
  enable_restricted = local.hub_psc_ep_api_secure
  secure_tags = {
    egress_internet  = local.hub_secure_tags_egress_internet.id
    egress_private   = local.hub_secure_tags_egress_private.id
    ingress_internet = local.hub_secure_tags_ingress_internet.id
    ingress_private  = local.hub_secure_tags_ingress_private.id
  }
}

module "hub_vpc_fw_policy" {
  source    = "../../modules/net-firewall-policy"
  parent_id = var.project_id_hub
  name      = "${local.hub_prefix}fw-policy"
  region    = "global"
  attachments = {
    hub-vpc = module.hub_vpc.self_link
  }
  description = "hub vpc firewall policy"
  # egress_rules  = local.hub_firewall_policy_egress_rules
  # ingress_rules = local.hub_firewall_policy_ingress_rules
}
/*
####################################################
# psc endpoint for apis
####################################################

# address

resource "google_compute_global_address" "hub_psc_ep_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_hub
  name         = local.hub_psc_ep_api_fr_name
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = module.hub_vpc.self_link
  address      = local.hub_psc_ep_api_fr_addr
}

# forwarding rule

resource "google_compute_global_forwarding_rule" "hub_psc_ep_api_fr" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = local.hub_psc_ep_api_fr_name
  target                = local.hub_psc_ep_api_fr_target
  network               = module.hub_vpc.self_link
  ip_address            = google_compute_global_address.hub_psc_ep_api_fr_addr.id
  load_balancing_scheme = ""
}

####################################################
# dns policy
####################################################

resource "google_dns_policy" "hub_dns_policy" {
  provider                  = google-beta
  project                   = var.project_id_hub
  name                      = "${local.hub_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = module.hub_vpc.self_link }
}

####################################################
# dns response policy
####################################################

resource "time_sleep" "hub_dns_forward_to_dns_wait" {
  create_duration = "120s"
  depends_on = [
    module.hub_eu_dns,
    module.hub_us_dns,
  ]
}

# rules - local

locals {
  hub_dns_rp_rules = {
    drp-rule-hub-eu-psc-be-api-run = { dns_name = "${local.hub_eu_psc_be_api_run_dns}.", local_data = { A = { rrdatas = [local.hub_eu_alb_addr] } } }
    drp-rule-hub-us-psc-be-api-run = { dns_name = "${local.hub_us_psc_be_api_run_dns}.", local_data = { A = { rrdatas = [local.hub_us_alb_addr] } } }
    drp-rule-runapp                = { dns_name = "*.run.app.", local_data = { A = { rrdatas = [local.hub_psc_ep_api_fr_addr] } } }
    drp-rule-gcr                   = { dns_name = "*.gcr.io.", local_data = { A = { rrdatas = [local.hub_psc_ep_api_fr_addr] } } }
    drp-rule-apis                  = { dns_name = "*.googleapis.com.", local_data = { A = { rrdatas = [local.hub_psc_ep_api_fr_addr] } } }
    drp-rule-bypass-www            = { dns_name = "www.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-ouath2         = { dns_name = "oauth2.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-psc            = { dns_name = "*.p.googleapis.com.", behavior = "bypassResponsePolicy" }
  }
}

# policy

module "hub_dns_response_policy" {
  source     = "../../modules/dns-response-policy"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}drp"
  rules      = local.hub_dns_rp_rules
  networks = {
    hub = module.hub_vpc.self_link
  }
}

####################################################
# cloud dns
####################################################

# psc zone

module "hub_dns_psc" {
  source      = "../../modules/dns"
  project_id  = var.project_id_hub
  name        = "${local.hub_prefix}psc"
  description = "psc"
  zone_config = {
    domain = "${local.hub_psc_ep_api_fr_name}.p.googleapis.com."
    private = {
      client_networks = [
        module.hub_vpc.self_link,
      ]
    }
  }
  recordsets = {
    "A " = { ttl = 300, records = [local.hub_psc_ep_api_fr_addr] }
  }
  depends_on = [
    time_sleep.hub_dns_forward_to_dns_wait,
  ]
}

# local zone

module "hub_dns_private_zone" {
  source      = "../../modules/dns"
  project_id  = var.project_id_hub
  name        = "${local.hub_prefix}private"
  description = "local data"
  zone_config = {
    domain = "${local.hub_dns_zone}."
    private = {
      client_networks = [
        module.hub_vpc.self_link,
      ]
    }
  }
  recordsets = {
    "A ${local.hub_eu_vm_dns_prefix}"    = { ttl = 300, records = [local.hub_eu_vm_addr, ] },
    "A ${local.hub_us_vm_dns_prefix}"    = { ttl = 300, records = [local.hub_us_vm_addr, ] },
    "AAAA ${local.hub_eu_vm_dns_prefix}" = { ttl = 300, records = [local.hub_eu_vm_main_ipv6, ] },
    "AAAA ${local.hub_us_vm_dns_prefix}" = { ttl = 300, records = [local.hub_us_vm_main_ipv6, ] },
  }
}

# onprem zone

module "hub_dns_forward_to_onprem" {
  source      = "../../modules/dns"
  project_id  = var.project_id_hub
  name        = "${local.hub_prefix}to-onprem"
  description = "forward to onprem"
  zone_config = {
    domain = "${local.onprem_domain}."
    forwarding = {
      client_networks = [module.hub_vpc.self_link, ]
      forwarders = {
        (local.hub_eu_ns_addr) = "private"
        (local.hub_us_ns_addr) = "private"
      }
    }
  }
}

####################################################
# workload
####################################################

# instance

module "hub_eu_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-vm"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.hub_vpc_tags_gfe.parent) = local.hub_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
    addresses  = { internal = local.hub_eu_vm_addr }
  }]
  service_account = {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}

module "hub_us_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}us-vm"
  zone       = "${local.hub_us_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.hub_vpc_tags_gfe.parent) = local.hub_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
    addresses  = { internal = local.hub_us_vm_addr }
  }]
  service_account = {
    email  = module.hub_sa.email
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
  hub_files = {
    "output/hub-unbound.sh" = local.hub_unbound_config
  }
}

resource "local_file" "hub_files" {
  for_each = local.hub_files
  filename = each.key
  content  = each.value
}
*/
