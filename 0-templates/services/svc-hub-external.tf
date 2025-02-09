
locals {
  # hub_eu_alb_main_ipv6 = module.hub_eu_alb_vm.internal_ipv6
  # hub_us_alb_main_ipv6 = module.hub_us_alb_vm.internal_ipv6
  # hub_eu_elb_ipv6 = split("/", module.hub_eu_elb.forwarding_rule_addresses["fr-ipv6"])[0]
  # hub_us_elb_ipv6      = split("/", module.hub_us_elb.forwarding_rule_addresses["fr-ipv6"])[0]
}

####################################################
# internal passthrough lb: eu
####################################################

# instance

module "hub_eu_elb_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-elb"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.hub_vpc_tags_gfe.parent) = local.hub_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
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
# internal passthrough lb: eu
####################################################

# address

resource "google_compute_address" "hub_eu_elb" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-elb"
  region  = local.hub_eu_region
}

# elb

module "hub_eu_elb" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-ext?ref=v34.1.0"
  project_id = var.project_id_hub
  region     = local.hub_eu_region
  name       = "${local.hub_prefix}eu-elb"

  group_configs = {
    main = {
      zone        = "${local.hub_eu_region}-b"
      instances   = [module.hub_eu_elb_vm.self_link, ]
      named_ports = { (local.svc_web.name) = local.svc_web.port }
    }
  }
  forwarding_rules_config = {
    fr-ipv4 = {
      address    = google_compute_address.hub_eu_elb.address
      protocol   = "TCP"
      ports      = [local.svc_web.port, ]
      ip_version = "IPV4"
    }
    # fr-ipv6 = {
    #   protocol   = "TCP"
    #   ports      = [local.svc_web.port, ]
    #   ip_version = "IPV6"
    #   subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
    # }
  }
  backends = [{
    failover = false
    group    = module.hub_eu_elb.groups.main.self_link
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
/*
####################################################
# internal proxy lb: eu
####################################################

# instance

module "hub_eu_nlb_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-nlb"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.hub_vpc_tags_gfe.parent) = local.hub_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  }]
  service_account = {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}

# nlb

module "hub_eu_nlb" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-proxy-int?ref=v34.1.0"
  project_id = var.project_id_hub
  region     = local.hub_eu_region
  name       = "${local.hub_prefix}eu-nlb"

  address = local.hub_eu_nlb_addr
  # allow_global_access = true

  vpc_config = {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  }
  backend_service_config = {
    backends = [
      { group = module.hub_eu_nlb.groups.main.self_link }
    ]
  }
  group_configs = {
    main = {
      zone        = "${local.hub_eu_region}-b"
      instances   = [module.hub_eu_nlb_vm.self_link, ]
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
    nat_subnets          = [module.hub_vpc.subnets_psc["${local.hub_eu_region}/eu-psc-nlb-nat"].self_link]
    automatic_connection = true
  }
}

####################################################
# internal application lb: eu
####################################################

# instance

module "hub_eu_alb_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-alb"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.hub_vpc_tags_gfe.parent) = local.hub_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  }]
  service_account = {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}

# alb

module "hub_eu_alb" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-app-int?ref=v34.1.0"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-alb"
  region     = local.hub_eu_region
  address    = local.hub_eu_alb_addr

  vpc_config = {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  }

  urlmap_config = {
    default_service = "default"
    host_rules = [
      { path_matcher = "main", hosts = [local.hub_eu_alb_fqdn, ] },
      { path_matcher = "psc-bes", hosts = [local.hub_eu_psc_be_run_dns, ] }
    ]
    path_matchers = {
      main    = { default_service = "default" }
      psc-be = { default_service = "psc-bes" }
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
          group          = "psc-bes"
          balancing_mode = "UTILIZATION"
          max_rate       = { capacity_scaler = 1.0 }
        }
      ]
    }
  }
  group_configs = {
    main = {
      zone        = "${local.hub_eu_region}-b"
      instances   = [module.hub_eu_alb_vm.self_link, ]
      named_ports = { (local.svc_web.name) = local.svc_web.port }
    }
  }
  neg_configs = {
    psc-be = {
      psc = {
        region         = local.hub_eu_region
        target_service = local.hub_eu_psc_be_run_dns
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
    nat_subnets          = [module.hub_vpc.subnets_psc["${local.hub_eu_region}/eu-psc-alb-nat"].self_link]
    automatic_connection = true
  }
}

####################################################
# internal passthrough lb: hub-us
####################################################

# elb

module "hub_us_elb" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-int?ref=v34.1.0"
  project_id    = var.project_id_hub
  region        = local.hub_us_region
  name          = "${local.hub_prefix}us-elb"
  service_label = "${local.hub_prefix}us-elb"

  vpc_config = {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
  }
  group_configs = {
    main = {
      zone        = "${local.hub_us_region}-b"
      instances   = [module.hub_us_vm.self_link, ]
      named_ports = { (local.svc_web.name) = local.svc_web.port }
    }
  }
  forwarding_rules_config = {
    fr-ipv4 = {
      address    = local.hub_us_elb_addr
      protocol   = "TCP"                  # protocol required for geo routing, service attachment etc
      ports      = [local.svc_web.port, ] # port required for geo routing, service attachment etc
      ip_version = "IPV4"
    }
    fr-ipv6 = {
      protocol   = "TCP"
      ports      = [local.svc_web.port, ]
      ip_version = "IPV6"
    }
  }
  backends = [{
    failover = false
    group    = module.hub_us_elb.groups.main.self_link
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
      nat_subnets          = [module.hub_vpc.subnets_psc["${local.hub_us_region}/us-psc-elb-nat"].self_link]
      automatic_connection = true
    }
    fr-ipv6 = {
      nat_subnets          = [module.hub_vpc.subnets_psc["${local.hub_us_region}/us-psc-elb-nat6"].self_link]
      automatic_connection = true
    }
  }
}

####################################################
# internal proxy lb: us
####################################################

# instance

module "hub_us_nlb_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}us-nlb"
  zone       = "${local.hub_us_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.hub_vpc_tags_gfe.parent) = local.hub_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
  }]
  service_account = {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}

# nlb

module "hub_us_nlb" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-proxy-int?ref=v34.1.0"
  project_id = var.project_id_hub
  region     = local.hub_us_region
  name       = "${local.hub_prefix}us-nlb"

  address = local.hub_us_nlb_addr
  # allow_global_access = true

  vpc_config = {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
  }
  backend_service_config = {
    backends = [
      { group = module.hub_us_nlb.groups.main.self_link }
    ]
  }
  group_configs = {
    main = {
      zone        = "${local.hub_us_region}-b"
      instances   = [module.hub_us_nlb_vm.self_link, ]
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
    nat_subnets          = [module.hub_vpc.subnets_psc["${local.hub_us_region}/us-psc-nlb-nat"].self_link]
    automatic_connection = true
  }
}

####################################################
# internal application lb: us
####################################################

# instance

module "hub_us_alb_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}us-alb"
  zone       = "${local.hub_us_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  tag_bindings_firewall = {
    (local.hub_vpc_tags_gfe.parent) = local.hub_vpc_tags_gfe.id
  }
  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
  }]
  service_account = {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}

# alb

module "hub_us_alb" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-app-int?ref=v34.1.0"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}us-alb"
  region     = local.hub_us_region
  address    = local.hub_us_alb_addr

  vpc_config = {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
  }

  urlmap_config = {
    default_service = "default"
    host_rules = [
      { path_matcher = "main", hosts = [local.hub_us_alb_fqdn, ] },
      { path_matcher = "psc-bes", hosts = [local.hub_us_psc_be_run_dns, ] }
    ]
    path_matchers = {
      main    = { default_service = "default" }
      psc-be = { default_service = "psc-bes" }
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
          group          = "psc-bes"
          balancing_mode = "UTILIZATION"
          max_rate       = { capacity_scaler = 1.0 }
        }
      ]
    }
  }
  group_configs = {
    main = {
      zone        = "${local.hub_us_region}-b"
      instances   = [module.hub_us_alb_vm.self_link, ]
      named_ports = { (local.svc_web.name) = local.svc_web.port }
    }
  }
  neg_configs = {
    psc-be = {
      psc = {
        region         = local.hub_us_region
        target_service = local.hub_us_psc_be_run_dns
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

####################################################
# dns recordsets
####################################################

module "hub_dns_private_zone_records" {
  source      = "../../modules/dns-record"
  depends_on  = [module.hub_dns_private_zone, ]
  project_id  = var.project_id_hub
  name        = module.hub_dns_private_zone.name
  description = "local data"
  recordsets = {
    "A ${local.hub_eu_elb_dns_prefix}" = { ttl = 300, records = [local.hub_eu_elb_addr, ] },
    "A ${local.hub_eu_nlb_dns_prefix}" = { ttl = 300, records = [local.hub_eu_nlb_addr, ] },
    "A ${local.hub_eu_alb_dns_prefix}" = { ttl = 300, records = [local.hub_eu_alb_addr, ] },
    "A ${local.hub_us_elb_dns_prefix}" = { ttl = 300, records = [local.hub_us_elb_addr, ] },
    "A ${local.hub_us_nlb_dns_prefix}" = { ttl = 300, records = [local.hub_us_nlb_addr, ] },
    "A ${local.hub_us_alb_dns_prefix}" = { ttl = 300, records = [local.hub_us_alb_addr, ] },

    "AAAA ${local.hub_eu_elb_dns_prefix}" = { ttl = 300, records = [local.hub_eu_elb_ipv6, ] },
    "AAAA ${local.hub_us_elb_dns_prefix}" = { ttl = 300, records = [local.hub_us_elb_ipv6, ] },

    "A ${local.hub_geo_elb_prefix}" = {
      geo_routing = [
        { location = local.hub_eu_region,
          health_checked_targets = [{
            load_balancer_type = "regionalL4elb"
            ip_address         = module.hub_eu_elb.forwarding_rule_addresses["fr-ipv4"]
            port               = local.svc_web.port
            ip_protocol        = "tcp"
            network_url        = module.hub_vpc.self_link
            project            = var.project_id_hub
            region             = local.hub_eu_region
          }]
        },
        { location = local.hub_us_region,
          health_checked_targets = [{
            load_balancer_type = "regionalL4elb"
            ip_address         = module.hub_us_elb.forwarding_rule_addresses["fr-ipv4"]
            port               = local.svc_web.port
            ip_protocol        = "tcp"
            network_url        = module.hub_vpc.self_link
            project            = var.project_id_hub
            region             = local.hub_us_region
          }]
        }
      ]
    }
    # "AAAA ${local.hub_geo_elb_prefix}" = {
    #   geo_routing = [
    #     { location = local.hub_eu_region,
    #       health_checked_targets = [{
    #         load_balancer_type = "regionalL4elb"
    #         ip_address         = local.hub_eu_elb_ipv6
    #         port               = local.svc_web.port
    #         ip_protocol        = "tcp"
    #         network_url        = module.hub_vpc.self_link
    #         project            = var.project_id_hub
    #         region             = local.hub_eu_region
    #       }]
    #     },
    #     { location = local.hub_us_region,
    #       health_checked_targets = [{
    #         load_balancer_type = "regionalL4elb"
    #         ip_address         = local.hub_us_elb_ipv6
    #         port               = local.svc_web.port
    #         ip_protocol        = "tcp"
    #         network_url        = module.hub_vpc.self_link
    #         project            = var.project_id_hub
    #         region             = local.hub_us_region
    #       }]
    #     }
    #   ]
    # }
  }
}
*/
