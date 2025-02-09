
####################################################
# internal passthrough lb: eu
####################################################

# ilb

module "spoke1_eu_ilb" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-int?ref=v34.1.0"
  project_id    = var.project_id_spoke1
  region        = local.spoke1_eu_region
  name          = "${local.spoke1_prefix}eu-ilb"
  service_label = "${local.spoke1_prefix}eu-ilb"

  vpc_config = {
    network    = module.spoke1_vpc.self_link
    subnetwork = module.spoke1_vpc.subnet_self_links["${local.spoke1_eu_region}/eu-main"]
  }
  group_configs = {
    main = {
      zone        = "${local.spoke1_eu_region}-b"
      instances   = [module.spoke1_eu_vm.self_link, ]
      named_ports = { (local.svc_web.name) = local.svc_web.port }
    }
  }
  forwarding_rules_config = {
    fr-ipv4 = {
      address    = local.spoke1_eu_ilb_addr
      protocol   = "TCP"                  # NOTE: protocol required for geo routing, service attachment etc
      ports      = [local.svc_web.port, ] # NOTE: port required for geo routing, service attachment etc
      ip_version = "IPV4"
    }
  }
  backends = [{
    failover = false
    group    = module.spoke1_eu_ilb.groups.main.self_link
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
  service_attachments = {
    fr-ipv4 = {
      nat_subnets          = [module.spoke1_vpc.subnets_psc["${local.spoke1_eu_region}/eu-psc-ilb-nat"].self_link]
      automatic_connection = true
    }
    fr-ipv6 = {
      nat_subnets          = [module.spoke1_vpc.subnets_psc["${local.spoke1_eu_region}/eu-psc-ilb-nat6"].self_link]
      automatic_connection = true
    }
  }
}

####################################################
# internal proxy lb: eu
####################################################

# instance

module "spoke1_eu_nlb_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}eu-nlb"
  zone       = "${local.spoke1_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.spoke1_vpc_tags_gfe.parent) = local.spoke1_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
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

# nlb

module "spoke1_eu_nlb" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-proxy-int?ref=v34.1.0"
  project_id = var.project_id_spoke1
  region     = local.spoke1_eu_region
  name       = "${local.spoke1_prefix}eu-nlb"

  address = local.spoke1_eu_nlb_addr
  # allow_global_access = true

  vpc_config = {
    network    = module.spoke1_vpc.self_link
    subnetwork = module.spoke1_vpc.subnet_self_links["${local.spoke1_eu_region}/eu-main"]
  }
  backend_service_config = {
    backends = [
      { group = module.spoke1_eu_nlb.groups.main.self_link }
    ]
  }
  group_configs = {
    main = {
      zone        = "${local.spoke1_eu_region}-b"
      instances   = [module.spoke1_eu_nlb_vm.self_link, ]
      named_ports = { (local.svc_web.name) = local.svc_web.port }
    }
  }
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
  service_attachment = {
    nat_subnets          = [module.spoke1_vpc.subnets_psc["${local.spoke1_eu_region}/eu-psc-nlb-nat"].self_link]
    automatic_connection = true
  }
}

####################################################
# internal application lb: eu
####################################################

# instance

module "spoke1_eu_alb_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}eu-alb"
  zone       = "${local.spoke1_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.spoke1_vpc_tags_gfe.parent) = local.spoke1_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
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

# alb

module "spoke1_eu_alb" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-app-int?ref=v34.1.0"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}eu-alb"
  region     = local.spoke1_eu_region
  address    = local.spoke1_eu_alb_addr

  vpc_config = {
    network    = module.spoke1_vpc.self_link
    subnetwork = module.spoke1_vpc.subnet_self_links["${local.spoke1_eu_region}/eu-main"]
  }

  urlmap_config = {
    default_service = "default"
    host_rules = [
      { path_matcher = "main", hosts = [local.spoke1_eu_alb_fqdn, ] },
      { path_matcher = "psc-be", hosts = [local.spoke1_eu_psc_be_run_dns, ] }
    ]
    path_matchers = {
      main   = { default_service = "default" }
      psc-be = { default_service = "psc-be" }
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
    psc-be = {
      health_checks = []
      backends = [
        {
          group          = "psc-be"
          balancing_mode = "UTILIZATION"
          max_rate       = { capacity_scaler = 1.0 }
        }
      ]
    }
  }
  group_configs = {
    main = {
      zone        = "${local.spoke1_eu_region}-b"
      instances   = [module.spoke1_eu_alb_vm.self_link, ]
      named_ports = { (local.svc_web.name) = local.svc_web.port }
    }
  }
  neg_configs = {
    psc-be = {
      psc = {
        region         = local.spoke1_eu_region
        target_service = local.spoke1_eu_psc_be_run_dns
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
  service_attachment = {
    nat_subnets          = [module.spoke1_vpc.subnets_psc["${local.spoke1_eu_region}/eu-psc-alb-nat"].self_link]
    automatic_connection = true
  }
}

####################################################
# psc endpoints --> spoke1
####################################################

# ipv4
#--------------------------------------

# ilb

resource "google_compute_address" "hub_eu_psc_spoke1_eu_ilb_fr_ipv4" {
  provider     = google-beta
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-psc-spoke1-eu-ilb-fr-ipv4"
  region       = local.hub_eu_region
  subnetwork   = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  address      = local.hub_eu_ep_spoke1_eu_psc_ilb_addr
  address_type = "INTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_forwarding_rule" "hub_eu_psc_spoke1_eu_ilb_fr_ipv4" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = "${local.hub_prefix}eu-psc-spoke1-eu-ilb-fr-ipv4"
  region                = local.hub_eu_region
  network               = module.hub_vpc.self_link
  target                = module.spoke1_eu_ilb.service_attachment_ids["fr-ipv4"]
  ip_address            = google_compute_address.hub_eu_psc_spoke1_eu_ilb_fr_ipv4.id
  load_balancing_scheme = ""
}

# nlb

resource "google_compute_address" "hub_eu_psc_spoke1_eu_nlb_fr_ipv4" {
  provider     = google-beta
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-psc-spoke1-eu-nlb-fr-ipv4"
  region       = local.hub_eu_region
  subnetwork   = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  address      = local.hub_eu_ep_spoke1_eu_psc_nlb_addr
  address_type = "INTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_forwarding_rule" "hub_eu_psc_spoke1_eu_nlb_fr_ipv4" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = "${local.hub_prefix}eu-psc-spoke1-eu-nlb-fr-ipv4"
  region                = local.hub_eu_region
  network               = module.hub_vpc.self_link
  target                = module.spoke1_eu_nlb.service_attachment_id
  ip_address            = google_compute_address.hub_eu_psc_spoke1_eu_nlb_fr_ipv4.id
  load_balancing_scheme = ""
}

# alb

resource "google_compute_address" "hub_eu_psc_spoke1_eu_alb_fr_ipv4" {
  provider     = google-beta
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-psc-spoke1-eu-alb-fr-ipv4"
  region       = local.hub_eu_region
  subnetwork   = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  address      = local.hub_eu_ep_spoke1_eu_psc_alb_addr
  address_type = "INTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_forwarding_rule" "hub_eu_psc_spoke1_eu_alb_fr_ipv4" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = "${local.hub_prefix}eu-psc-spoke1-eu-alb-fr-ipv4"
  region                = local.hub_eu_region
  network               = module.hub_vpc.self_link
  target                = module.spoke1_eu_alb.service_attachment_id
  ip_address            = google_compute_address.hub_eu_psc_spoke1_eu_alb_fr_ipv4.id
  load_balancing_scheme = ""
}

####################################################
# dns recordsets
####################################################

module "spoke1_dns_private_zone_records" {
  source      = "../../modules/dns-record"
  depends_on  = [module.spoke1_dns_private_zone, ]
  project_id  = var.project_id_spoke1
  name        = module.spoke1_dns_private_zone.name
  description = "spoke1 network attached"

  recordsets = {
    "A ${local.spoke1_eu_ilb_dns_prefix}" = { ttl = 300, records = [local.spoke1_eu_ilb_addr] },
    "A ${local.spoke1_eu_nlb_dns_prefix}" = { ttl = 300, records = [local.spoke1_eu_nlb_addr] },
    "A ${local.spoke1_eu_alb_dns_prefix}" = { ttl = 300, records = [local.spoke1_eu_alb_addr] },
  }
}
