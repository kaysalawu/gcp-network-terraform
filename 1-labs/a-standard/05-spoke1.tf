
# dns policy
#---------------------------------

resource "google_dns_policy" "spoke1_dns_policy" {
  provider                  = google-beta
  project                   = var.project_id_spoke1
  name                      = "${local.spoke1_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = module.spoke1_vpc.self_link }
}

# dns response policy
#---------------------------------

# rules - local

locals {
  spoke1_dns_rp_rules = {
    drp-rule-eu-psc-https-ctrl = { dns_name = "${local.spoke1_eu_psc_https_ctrl_run_dns}.", local_data = { A = { rrdatas = [local.spoke1_eu_ilb7_addr] } } }
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
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns-response-policy?ref=v33.0.0"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}drp"
  rules      = local.spoke1_dns_rp_rules
  networks = {
    spoke1 = module.spoke1_vpc.self_link
  }
}

# cloud dns
#---------------------------------

# psc zone

module "spoke1_dns_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v33.0.0"
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
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v33.0.0"
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
    "A ${local.spoke1_eu_vm_dns_prefix}"   = { ttl = 300, records = [local.spoke1_eu_vm_addr] },
    "A ${local.spoke1_us_vm_dns_prefix}"   = { ttl = 300, records = [local.spoke1_us_vm_addr] },
    "A ${local.spoke1_eu_ilb4_dns_prefix}" = { ttl = 300, records = [local.spoke1_eu_ilb4_addr] },
    "A ${local.spoke1_us_ilb4_dns_prefix}" = { ttl = 300, records = [local.spoke1_us_ilb4_addr] },
    "A ${local.spoke1_eu_ilb7_dns_prefix}" = { ttl = 300, records = [local.spoke1_eu_ilb7_addr] },
    "A ${local.spoke1_us_ilb7_dns_prefix}" = { ttl = 300, records = [local.spoke1_us_ilb7_addr] },
  }
}

# onprem zone

module "spoke1_dns_peering_to_hub_to_onprem" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v33.0.0"
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
    "PTR ${local.spoke1_eu_ilb4_reverse_suffix}" = { ttl = 300, records = ["${local.spoke1_eu_ilb4_fqdn}."] },
    "PTR ${local.spoke1_eu_ilb7_reverse_suffix}" = { ttl = 300, records = ["${local.spoke1_eu_ilb7_fqdn}."] },
  }
}

# ilb4 - eu
#---------------------------------

# instance

module "spoke1_eu_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}eu-vm"
  zone       = "${local.spoke1_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  network_interfaces = [{
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

# instance group

resource "google_compute_instance_group" "spoke1_eu_ilb4_ig" {
  project = var.project_id_spoke1
  zone    = "${local.spoke1_eu_region}-b"
  name    = "${local.spoke1_prefix}eu-ilb4-ig"
  instances = [
    module.spoke1_eu_vm.self_link,
  ]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# ilb4

module "spoke1_eu_ilb4" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-int?ref=v33.0.0"
  project_id    = var.project_id_spoke1
  region        = local.spoke1_eu_region
  name          = "${local.spoke1_prefix}eu-ilb4"
  service_label = "${local.spoke1_prefix}eu-ilb4"

  vpc_config = {
    network    = module.spoke1_vpc.self_link
    subnetwork = module.spoke1_vpc.subnet_self_links["${local.spoke1_eu_region}/eu-main"]
  }
  forwarding_rules_config = {
    fr = {
      address  = local.spoke1_eu_ilb4_addr
      target   = google_compute_instance_group.spoke1_eu_ilb4_ig.self_link
      protocol = "L3_DEFAULT"
    }
  }
  backends = [{
    failover = false
    group    = google_compute_instance_group.spoke1_eu_ilb4_ig.self_link
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

# ilb7: spoke1-eu
#---------------------------------

# instance

module "spoke1_eu_vm7" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}eu-vm7"
  zone       = "${local.spoke1_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  network_interfaces = [{
    network    = module.spoke1_vpc.self_link
    subnetwork = module.spoke1_vpc.subnet_self_links["${local.spoke1_eu_region}/eu-main"]
  }]
  service_account = {
    email  = module.spoke1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}

# ilb7

module "spoke1_eu_ilb7" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-app-int?ref=v33.0.0"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}eu-ilb7"
  region     = local.spoke1_eu_region
  address    = local.spoke1_eu_ilb7_addr

  vpc_config = {
    network    = module.spoke1_vpc.self_link
    subnetwork = module.spoke1_vpc.subnet_self_links["${local.spoke1_eu_region}/eu-main"]
  }

  urlmap_config = {
    default_service = "default"
    host_rules = [
      { path_matcher = "main", hosts = [local.spoke1_eu_ilb7_fqdn, ] },
      { path_matcher = "psc-neg", hosts = [local.spoke1_eu_psc_https_ctrl_run_dns, ] }
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
      zone        = "${local.spoke1_eu_region}-b"
      instances   = [module.spoke1_eu_vm7.self_link, ]
      named_ports = { (local.svc_web.name) = local.svc_web.port }
    }
  }
  neg_configs = {
    psc-neg = {
      psc = {
        region         = local.spoke1_eu_region
        target_service = local.spoke1_eu_psc_https_ctrl_run_dns
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
