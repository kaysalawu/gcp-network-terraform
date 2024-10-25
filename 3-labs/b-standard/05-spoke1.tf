
locals {
  spoke1_eu_vm_main_ipv6 = module.spoke1_eu_vm.internal_ipv6
}

####################################################
# dns policy
####################################################

resource "google_dns_policy" "spoke1_dns_policy" {
  provider                  = google-beta
  project                   = var.project_id_spoke1
  name                      = "${local.spoke1_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = module.spoke1_vpc.self_link }
}

####################################################
# dns response policy
####################################################

# rules - local

locals {
  spoke1_dns_rp_rules = {
    drp-rule-eu-psc-https-ctrl = { dns_name = "${local.spoke1_eu_psc_https_ctrl_run_dns}.", local_data = { A = { rrdatas = [local.spoke1_eu_alb_addr] } } }
    drp-rule-us-psc-https-ctrl = { dns_name = "${local.spoke1_us_psc_https_ctrl_run_dns}.", local_data = { A = { rrdatas = [local.spoke1_psc_api_fr_addr] } } }
    drp-rule-runapp            = { dns_name = "*.run.app.", local_data = { A = { rrdatas = [local.spoke1_psc_api_fr_addr] } } }
    drp-rule-gcr               = { dns_name = "*.gcr.io.", local_data = { A = { rrdatas = [local.spoke1_psc_api_fr_addr] } } }
    drp-rule-apis              = { dns_name = "*.googleapis.com.", local_data = { A = { rrdatas = [local.spoke1_psc_api_fr_addr] } } }
    drp-rule-bypass-www        = { dns_name = "www.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-ouath2     = { dns_name = "oauth2.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-psc        = { dns_name = "*.p.googleapis.com.", behavior = "bypassResponsePolicy" }
  }
}

# policy

module "spoke1_dns_response_policy" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns-response-policy?ref=v34.1.0"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}drp"
  rules      = local.spoke1_dns_rp_rules
  networks = {
    spoke1 = module.spoke1_vpc.self_link
  }
}

####################################################
# cloud dns
####################################################

# psc zone

module "spoke1_dns_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v34.1.0"
  project_id  = var.project_id_spoke1
  name        = "${local.spoke1_prefix}psc"
  description = "psc"
  zone_config = {
    domain = "${local.spoke1_psc_api_fr_name}.p.googleapis.com."
    private = {
      client_networks = [
        module.hub_vpc.self_link,
        module.spoke1_vpc.self_link,
        module.spoke2_vpc.self_link
      ]
    }
  }
  recordsets = {
    "A " = { ttl = 300, records = [local.spoke1_psc_api_fr_addr] }
  }
  depends_on = [
    time_sleep.hub_dns_forward_to_dns_wait,
  ]
}

# local zone

module "spoke1_dns_private_zone" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v34.1.0"
  project_id  = var.project_id_spoke1
  name        = "${local.spoke1_prefix}private"
  description = "spoke1 network attached"
  zone_config = {
    domain = "${local.spoke1_domain}.${local.cloud_domain}."
    private = {
      client_networks = [
        module.hub_vpc.self_link,
        module.spoke1_vpc.self_link,
        module.spoke2_vpc.self_link,
      ]
    }
  }
  recordsets = {
    "A ${local.spoke1_eu_vm_dns_prefix}"    = { ttl = 300, records = [local.spoke1_eu_vm_addr] },
    "AAAA ${local.spoke1_eu_vm_dns_prefix}" = { ttl = 300, records = [local.spoke1_eu_vm_main_ipv6] },
  }
}

# onprem zone

module "spoke1_dns_peering_to_hub_to_onprem" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v34.1.0"
  project_id  = var.project_id_spoke1
  name        = "${local.spoke1_prefix}to-hub-to-onprem"
  description = "peering to hub for onprem"
  zone_config = {
    domain = "${local.onprem_domain}."
    peering = {
      client_networks = [module.spoke1_vpc.self_link]
      peer_network    = module.hub_vpc.self_link
    }
  }
}

# reverse lookup zone (self-managed reverse lookup zones)

module "spoke1_reverse_zone" {
  source      = "../../modules/dns"
  project_id  = var.project_id_spoke1
  name        = "${local.spoke1_prefix}reverse-zone"
  description = "spoke1 reverse zone"
  zone_config = {
    domain = local.spoke1_reverse_zone
    private = {
      client_networks = [
        module.hub_vpc.self_link,
        module.spoke1_vpc.self_link,
        module.spoke2_vpc.self_link,
      ]
    }
  }
  recordsets = {
    "PTR ${local.spoke1_eu_ilb_reverse_suffix}" = { ttl = 300, records = ["${local.spoke1_eu_ilb_fqdn}."] },
    "PTR ${local.spoke1_eu_alb_reverse_suffix}" = { ttl = 300, records = ["${local.spoke1_eu_alb_fqdn}."] },
  }
}


####################################################
# workload
####################################################

# instance

module "spoke1_eu_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}eu-vm"
  zone       = "${local.spoke1_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.spoke1_vpc_tags_gfe.parent) = local.spoke1_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.spoke1_vpc.self_link
    subnetwork = module.spoke1_vpc.subnet_self_links["${local.spoke1_eu_region}/eu-main"]
    addresses  = { internal = local.spoke1_eu_vm_addr }
  }]
  service_account = {
    email  = module.spoke1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}
