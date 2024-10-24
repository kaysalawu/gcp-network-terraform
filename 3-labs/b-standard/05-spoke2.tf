
locals {
  spoke2_vpc_tags = {
    "${local.spoke2_prefix}vpc-dns" = { value = "dns", description = "custom dns servers" }
    "${local.spoke2_prefix}vpc-gfe" = { value = "gfe", description = "load balancer backends" }
    "${local.spoke2_prefix}vpc-nva" = { value = "nva", description = "nva appliances" }
  }
  spoke2_vpc_tags_dns = google_tags_tag_value.spoke2_vpc_tags["${local.spoke2_prefix}vpc-dns"]
  spoke2_vpc_tags_gfe = google_tags_tag_value.spoke2_vpc_tags["${local.spoke2_prefix}vpc-gfe"]
  spoke2_vpc_tags_nva = google_tags_tag_value.spoke2_vpc_tags["${local.spoke2_prefix}vpc-nva"]

  spoke2_vpc_ipv6_cidr   = module.spoke2_vpc.internal_ipv6_range
  spoke2_eu_vm_main_ipv6 = module.spoke2_eu_vm.internal_ipv6
  spoke2_us_vm_main_ipv6 = module.spoke2_us_vm.internal_ipv6
  spoke2_us_ilb4_ipv6    = split("/", module.spoke2_us_ilb4.forwarding_rule_addresses["fr-ipv6"])[0]
}

####################################################
# network
####################################################

module "spoke2_vpc" {
  # source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v33.0.0"
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

  psa_configs = [{
    ranges = {
      "spoke2-us-psa-range1" = local.spoke2_us_psa_range1
      "spoke2-us-psa-range2" = local.spoke2_us_psa_range2
    }
    export_routes  = true
    import_routes  = true
    peered_domains = ["gcp.example.com."]
  }]
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

# ####################################################
# # service networking connection
# ####################################################

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
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v33.0.0"
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
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v33.0.0"
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

# policy

module "spoke2_vpc_fw_policy" {
  source    = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-firewall-policy?ref=v33.0.0"
  name      = "${local.spoke2_prefix}vpc-fw-policy"
  parent_id = var.project_id_spoke2
  region    = "global"
  attachments = {
    spoke2-vpc = module.spoke2_vpc.self_link
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
    #ipv6
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
      target_tags = [local.spoke2_vpc_tags_dns.id, local.spoke2_vpc_tags_nva.id, ]
      match = {
        source_ranges  = local.netblocks.dns
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
    }
    ssh = {
      priority       = 1200
      target_tags    = [local.spoke2_vpc_tags_nva.id, ]
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
      target_tags = [local.spoke2_vpc_tags_nva.id, ]
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
      target_tags = [local.spoke2_vpc_tags_gfe.id, ]
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
      target_tags    = [local.spoke2_vpc_tags_nva.id, ]
      enable_logging = true
      match = {
        source_ranges  = ["0::/0", ]
        layer4_configs = [{ protocol = "tcp", ports = ["22"] }]
      }
    }
    vpn-6 = {
      priority    = 1401
      target_tags = [local.spoke2_vpc_tags_nva.id, ]
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
      target_tags = [local.spoke2_vpc_tags_gfe.id, ]
      match = {
        source_ranges  = local.netblocks_ipv6.gfe
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
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
  name         = "${local.spoke2_prefix}${local.spoke2_psc_api_fr_name}"
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
# psc endpoints (spoke1 services)
####################################################

# internal pass-through lb (ipv4)
#------------------------------------

# address

resource "google_compute_address" "spoke2_eu_psc_spoke1_eu_ilb4_fr_ipv4" {
  provider     = google-beta
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}eu-psc-spoke1-eu-ilb4-fr-ipv4"
  region       = local.spoke2_eu_region
  subnetwork   = module.spoke2_vpc.subnet_self_links["${local.spoke2_eu_region}/eu-main"]
  address      = local.spoke2_eu_ep_spoke1_eu_psc_ilb4_addr
  address_type = "INTERNAL"
  ip_version   = "IPV4"
}

# forwarding rule

# resource "google_compute_forwarding_rule" "spoke2_eu_psc_spoke1_eu_ilb4_fr_ipv4" {
#   provider              = google-beta
#   project               = var.project_id_spoke2
#   name                  = "${local.spoke2_prefix}eu-psc-spoke1-eu-ilb4-fr-ipv4"
#   region                = local.spoke2_eu_region
#   network               = module.spoke2_vpc.self_link
#   target                = module.spoke1_eu_ilb4.service_attachment_ids["fr-ipv4"]
#   ip_address            = google_compute_address.spoke2_eu_psc_spoke1_eu_ilb4_fr_ipv4.id
#   load_balancing_scheme = ""
# }

# internal pass-through lb (ipv6)
#------------------------------------

# address

resource "google_compute_address" "spoke2_eu_psc_spoke1_eu_ilb4_fr_ipv6" {
  provider     = google-beta
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}eu-psc-spoke1-eu-ilb4-fr-ipv6"
  region       = local.spoke2_eu_region
  subnetwork   = module.spoke2_vpc.subnet_self_links["${local.spoke2_eu_region}/eu-main"]
  address_type = "INTERNAL"
  ip_version   = local.enable_ipv6 ? "IPV6" : null
}

# forwarding rule

resource "google_compute_forwarding_rule" "spoke2_eu_psc_spoke1_eu_ilb4_fr_ipv6" {
  provider              = google-beta
  project               = var.project_id_spoke2
  name                  = "${local.spoke2_prefix}eu-psc-spoke1-eu-ilb4-fr-ipv6"
  region                = local.spoke2_eu_region
  network               = module.spoke2_vpc.self_link
  target                = module.spoke1_eu_ilb4.service_attachment_ids["fr-ipv6"]
  ip_address            = google_compute_address.spoke2_eu_psc_spoke1_eu_ilb4_fr_ipv6.id
  load_balancing_scheme = ""
  ip_version            = local.enable_ipv6 ? "IPV6" : null
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
    drp-rule-eu-psc-https-ctrl = { dns_name = "${local.spoke2_eu_psc_https_ctrl_run_dns}.", local_data = { A = { rrdatas = [local.spoke2_eu_ilb7_addr] } } }
    drp-rule-us-psc-https-ctrl = { dns_name = "${local.spoke2_us_psc_https_ctrl_run_dns}.", local_data = { A = { rrdatas = [local.spoke2_us_ilb7_addr] } } }
    drp-rule-runapp            = { dns_name = "*.run.app.", local_data = { A = { rrdatas = [local.spoke2_psc_api_fr_addr] } } }
    drp-rule-gcr               = { dns_name = "*.gcr.io.", local_data = { A = { rrdatas = [local.spoke2_psc_api_fr_addr] } } }
    drp-rule-apis              = { dns_name = "*.googleapis.com.", local_data = { A = { rrdatas = [local.spoke2_psc_api_fr_addr] } } }
    drp-rule-bypass-www        = { dns_name = "www.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-ouath2     = { dns_name = "oauth2.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-psc        = { dns_name = "*.p.googleapis.com.", behavior = "bypassResponsePolicy" }
  }
}

# policy

module "spoke2_dns_response_policy" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns-response-policy?ref=v33.0.0"
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
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v33.0.0"
  project_id  = var.project_id_spoke2
  name        = "${local.spoke2_prefix}psc"
  description = "psc"
  zone_config = {
    domain = "${local.spoke2_psc_api_fr_name}.p.googleapis.com."
    private = {
      client_networks = [
        module.hub_vpc.self_link,
        module.spoke1_vpc.self_link,
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
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v33.0.0"
  project_id  = var.project_id_spoke2
  name        = "${local.spoke2_prefix}private"
  description = "spoke2 network attached"
  zone_config = {
    domain = "${local.spoke2_domain}.${local.cloud_domain}."
    private = {
      client_networks = [
        module.hub_vpc.self_link,
        module.spoke1_vpc.self_link,
        module.spoke2_vpc.self_link,
      ]
    }
  }
  recordsets = {
    "A ${local.spoke2_eu_vm_dns_prefix}"                = { ttl = 300, records = [local.spoke2_eu_vm_addr] },
    "A ${local.spoke2_eu_ep_spoke1_eu_psc_ilb4_prefix}" = { ttl = 300, records = [local.spoke2_eu_ep_spoke1_eu_psc_ilb4_addr] },

    "A ${local.spoke2_us_vm_dns_prefix}"   = { ttl = 300, records = [local.spoke2_us_vm_addr] },
    "A ${local.spoke2_us_ilb4_dns_prefix}" = { ttl = 300, records = [local.spoke2_us_ilb4_addr] },
    "A ${local.spoke2_us_nlb4_dns_prefix}" = { ttl = 300, records = [local.spoke2_us_nlb4_addr] },
    "A ${local.spoke2_us_ilb7_dns_prefix}" = { ttl = 300, records = [local.spoke2_us_ilb7_addr] },

    "AAAA ${local.spoke2_eu_vm_dns_prefix}" = { ttl = 300, records = [local.spoke2_eu_vm_main_ipv6] },

    "AAAA ${local.spoke2_us_vm_dns_prefix}"   = { ttl = 300, records = [local.spoke2_us_vm_main_ipv6] },
    "AAAA ${local.spoke2_us_ilb4_dns_prefix}" = { ttl = 300, records = [local.spoke2_us_ilb4_ipv6] },
  }
}

# onprem zone

module "spoke2_dns_peering_to_hub_to_onprem" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v33.0.0"
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
        module.spoke1_vpc.self_link,
        module.spoke2_vpc.self_link,
      ]
    }
  }
  recordsets = {
    "PTR ${local.spoke2_us_ilb4_reverse_suffix}" = { ttl = 300, records = ["${local.spoke2_eu_ilb4_fqdn}."] },
    "PTR ${local.spoke2_us_ilb7_reverse_suffix}" = { ttl = 300, records = ["${local.spoke2_eu_ilb7_fqdn}."] },
  }
}

####################################################
# vm - us
####################################################

# instance

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

####################################################
# ilb4 - us
####################################################

# instance

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

# ilb4

module "spoke2_us_ilb4" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-int?ref=v33.0.0"
  project_id    = var.project_id_spoke2
  region        = local.spoke2_us_region
  name          = "${local.spoke2_prefix}us-ilb4"
  service_label = "${local.spoke2_prefix}us-ilb4"

  vpc_config = {
    network    = module.spoke2_vpc.self_link
    subnetwork = module.spoke2_vpc.subnet_self_links["${local.spoke2_us_region}/us-main"]
  }
  group_configs = {
    main = {
      zone        = "${local.spoke2_us_region}-b"
      instances   = [module.spoke2_us_vm.self_link, ]
      named_ports = { (local.svc_web.name) = local.svc_web.port }
    }
  }
  forwarding_rules_config = {
    fr-ipv4 = {
      address    = local.spoke2_us_ilb4_addr
      protocol   = "L3_DEFAULT"
      ip_version = "IPV4"
    }
    fr-ipv6 = {
      protocol   = "L3_DEFAULT"
      ip_version = "IPV6"
    }
  }
  backends = [{
    failover = false
    group    = module.spoke2_us_ilb4.groups.main.self_link
  }]
  health_check_config = {
    enable_logging = true
    http = {
      host               = local.uhc_config.host
      port               = local.svc_web.port
      port_specification = "USE_FIXED_PORT"
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
    }
  }
}

####################################################
# ilb7: spoke2-us
####################################################

# instance

module "spoke2_us_vm7" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}us-vm7"
  zone       = "${local.spoke2_us_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.spoke2_vpc_tags_gfe.parent) = local.spoke2_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.spoke2_vpc.self_link
    subnetwork = module.spoke2_vpc.subnet_self_links["${local.spoke2_us_region}/us-main"]
  }]
  service_account = {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}

# ilb7

module "spoke2_us_ilb7" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-app-int?ref=v34.1.0"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}us-ilb7"
  region     = local.spoke2_us_region
  address    = local.spoke2_us_ilb7_addr

  vpc_config = {
    network    = module.spoke2_vpc.self_link
    subnetwork = module.spoke2_vpc.subnet_self_links["${local.spoke2_us_region}/us-main"]
  }

  urlmap_config = {
    default_service = "default"
    host_rules = [
      { path_matcher = "main", hosts = [local.spoke2_us_ilb7_fqdn, ] },
      { path_matcher = "psc-neg", hosts = [local.spoke2_us_psc_https_ctrl_run_dns, ] }
    ]
    path_matchers = {
      main    = { default_service = "default" }
      psc-neg = { default_service = "psc-neg" }
    }
  }
  backend_service_configs = {
    default = {
      port_name     = local.svc_web.name
      health_checks = ["custom-http"]
      backends = [
        {
          group          = "main"
          balancing_mode = "RATE"
          max_rate       = { per_instance = 100, capacity_scaler = 1.0 }
        },
      ]
    }
    psc-neg = {
      health_checks = []
      backends = [
        {
          group          = "psc-neg"
          balancing_mode = "UTILIZATION"
          max_rate       = { capacity_scaler = 1.0 }
        }
      ]
    }
  }
  group_configs = {
    main = {
      zone        = "${local.spoke2_us_region}-b"
      instances   = [module.spoke2_us_vm7.self_link, ]
      named_ports = { (local.svc_web.name) = local.svc_web.port }
    }
  }
  neg_configs = {
    psc-neg = {
      psc = {
        region         = local.spoke2_us_region
        target_service = local.spoke2_us_psc_https_ctrl_run_dns
      }
    }
  }
  health_check_configs = {
    custom-http = {
      enable_logging = true
      http = {
        host               = local.uhc_config.host
        port_specification = "USE_SERVING_PORT"
        request_path       = "/${local.uhc_config.request_path}"
        response           = local.uhc_config.response
      }
    }
  }
}
