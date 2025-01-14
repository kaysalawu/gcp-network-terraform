
locals {
  hub_vpc_tags = {
    "${local.hub_prefix}vpc-dns" = { value = "dns", description = "custom dns servers" }
    "${local.hub_prefix}vpc-gfe" = { value = "gfe", description = "load balancer backends" }
    "${local.hub_prefix}vpc-nva" = { value = "nva", description = "nva appliances" }
  }
  hub_vpc_ipv6_cidr   = module.hub_vpc.internal_ipv6_range
  hub_eu_vm_main_ipv6 = module.hub_eu_vm.internal_ipv6
}

####################################################
# network
####################################################

module "hub_vpc" {
  source     = "../../modules/net-vpc"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}vpc"

  subnets             = local.hub_subnets_list
  subnets_private_nat = local.hub_subnets_private_nat_list
  subnets_proxy_only  = local.hub_subnets_proxy_only_list
  subnets_psc         = local.hub_subnets_psc_list

  ipv6_config = {
    enable_ula_internal = true
  }
}

####################################################
# nat
####################################################

# addresses

resource "google_compute_address" "hub_nat_eu" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-nat"
  region  = local.hub_eu_region
}

# nat

module "hub_nat_eu" {
  source         = "../../modules/net-cloudnat"
  project_id     = var.project_id_hub
  region         = local.hub_eu_region
  name           = "${local.hub_prefix}eu-nat"
  router_network = module.hub_vpc.self_link
  router_create  = true
  addresses = [
    google_compute_address.hub_nat_eu.self_link,
  ]

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

module "hub_vpc_firewall" {
  source     = "../../modules/net-vpc-firewall"
  project_id = var.project_id_hub
  network    = module.hub_vpc.name

  egress_rules = {
    "${local.hub_prefix}allow-egress-all" = {
      priority           = 1000
      deny               = false
      description        = "allow egress"
      destination_ranges = ["0.0.0.0/0", ]
      rules              = [{ protocol = "all", ports = [] }]
    }
    # ipv6
    "${local.hub_prefix}allow-egress-smtp-ipv6" = {
      priority           = 901
      description        = "block smtp"
      destination_ranges = ["::/0", ]
      rules              = [{ protocol = "tcp", ports = [25, ] }]
    }
    "${local.hub_prefix}allow-egress-all-ipv6" = {
      priority           = 1001
      deny               = false
      description        = "allow egress"
      destination_ranges = ["::/0", ]
      rules              = [{ protocol = "all", ports = [] }]
    }
  }
  ingress_rules = {
    # ipv4
    "${local.hub_prefix}allow-ingress-internal" = {
      priority      = 1000
      description   = "allow internal"
      source_ranges = local.netblocks.internal
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.hub_prefix}allow-ingress-dns" = {
      priority      = 1100
      description   = "allow dns"
      source_ranges = local.netblocks.dns
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.hub_prefix}allow-ingress-ssh" = {
      priority       = 1200
      description    = "allow ingress ssh"
      source_ranges  = ["0.0.0.0/0"]
      targets        = [local.tag_router]
      rules          = [{ protocol = "tcp", ports = [22] }]
      enable_logging = {}
    }
    "${local.hub_prefix}allow-ingress-iap" = {
      priority       = 1300
      description    = "allow ingress iap"
      source_ranges  = local.netblocks.iap
      targets        = [local.tag_router]
      rules          = [{ protocol = "all", ports = [] }]
      enable_logging = {}
    }
    "${local.hub_prefix}allow-ingress-dns-proxy" = {
      priority      = 1400
      description   = "allow dns egress proxy"
      source_ranges = local.netblocks.dns
      targets       = [local.tag_dns]
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.hub_prefix}allow-ingress-gfe" = {
      priority      = 1000
      description   = "allow internal"
      source_ranges = local.netblocks.gfe
      rules         = [{ protocol = "all", ports = [] }]
    }
    # ipv6
    "${local.hub_prefix}allow-ingress-internal-ipv6" = {
      priority      = 1000
      description   = "allow internal"
      source_ranges = local.netblocks_ipv6.internal
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.hub_prefix}allow-ingress-ssh-ipv6" = {
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
# psc/api
####################################################

# address

resource "google_compute_global_address" "hub_psc_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_hub
  name         = local.hub_psc_api_fr_name
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = module.hub_vpc.self_link
  address      = local.hub_psc_api_fr_addr
}

# forwarding rule

resource "google_compute_global_forwarding_rule" "hub_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = local.hub_psc_api_fr_name
  target                = local.hub_psc_api_fr_target
  network               = module.hub_vpc.self_link
  ip_address            = google_compute_global_address.hub_psc_api_fr_addr.id
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

# rules - local

locals {
  hub_dns_rp_rules = {
    drp-rule-eu-psc-https-ctrl = { dns_name = "${local.hub_eu_psc_https_ctrl_run_dns}.", local_data = { A = { rrdatas = [local.hub_eu_alb_addr] } } }
    drp-rule-us-psc-https-ctrl = { dns_name = "${local.hub_us_psc_https_ctrl_run_dns}.", local_data = { A = { rrdatas = [local.hub_us_alb_addr] } } }
    drp-rule-runapp            = { dns_name = "*.run.app.", local_data = { A = { rrdatas = [local.hub_psc_api_fr_addr] } } }
    drp-rule-gcr               = { dns_name = "*.gcr.io.", local_data = { A = { rrdatas = [local.hub_psc_api_fr_addr] } } }
    drp-rule-apis              = { dns_name = "*.googleapis.com.", local_data = { A = { rrdatas = [local.hub_psc_api_fr_addr] } } }
    drp-rule-bypass-www        = { dns_name = "www.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-ouath2     = { dns_name = "oauth2.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-psc        = { dns_name = "*.p.googleapis.com.", behavior = "bypassResponsePolicy" }
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
    domain = "${local.hub_psc_api_fr_name}.p.googleapis.com."
    private = {
      client_networks = [module.hub_vpc.self_link, ]
    }
  }
  recordsets = {
    "A " = { ttl = 300, records = [local.hub_psc_api_fr_addr] }
  }
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
      client_networks = [module.hub_vpc.self_link, ]
    }
  }
  recordsets = {
    "A ${local.hub_eu_vm_dns_prefix}"    = { ttl = 300, records = [local.hub_eu_vm_addr, ] },
    "A ${local.hub_us_vm_dns_prefix}"    = { ttl = 300, records = [local.hub_us_vm_addr, ] },
    "AAAA ${local.hub_eu_vm_dns_prefix}" = { ttl = 300, records = [local.hub_eu_vm_main_ipv6, ] },
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

####################################################
# output files
####################################################

locals {
  hub_files = {}
}

resource "local_file" "hub_files" {
  for_each = local.hub_files
  filename = each.key
  content  = each.value
}

output "neo4j_client_external_ip" {
  value = google_compute_address.hub_nat_eu.address
}
