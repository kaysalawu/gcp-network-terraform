
####################################################
# internal passthrough lb: us
####################################################

# ilb

module "spoke2_us_ilb" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-int?ref=v34.1.0"
  project_id    = var.project_id_spoke2
  region        = local.spoke2_us_region
  name          = "${local.spoke2_prefix}us-ilb"
  service_label = "${local.spoke2_prefix}us-ilb"

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
      address    = local.spoke2_us_ilb_addr
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
    group    = module.spoke2_us_ilb.groups.main.self_link
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
# internal proxy lb: us
####################################################

# instance

module "spoke2_us_nlb_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}us-nlb"
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

# nlb

module "spoke2_us_nlb" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-proxy-int?ref=v34.1.0"
  project_id = var.project_id_spoke2
  region     = local.spoke2_us_region
  name       = "${local.spoke2_prefix}us-nlb"

  vpc_config = {
    network    = module.spoke2_vpc.self_link
    subnetwork = module.spoke2_vpc.subnet_self_links["${local.spoke2_us_region}/us-main"]
  }
  backend_service_config = {
    backends = [
      { group = module.spoke2_us_nlb.groups.main.self_link }
    ]
  }
  group_configs = {
    main = {
      zone        = "${local.spoke2_us_region}-b"
      instances   = [module.spoke2_us_nlb_vm.self_link, ]
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
}

####################################################
# internal application lb: us
####################################################

# instance

module "spoke2_us_alb_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}us-alb"
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

# alb

module "spoke2_us_alb" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-lb-app-int?ref=v34.1.0"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}us-alb"
  region     = local.spoke2_us_region
  address    = local.spoke2_us_alb_addr

  vpc_config = {
    network    = module.spoke2_vpc.self_link
    subnetwork = module.spoke2_vpc.subnet_self_links["${local.spoke2_us_region}/us-main"]
  }

  urlmap_config = {
    default_service = "default"
    host_rules = [
      { path_matcher = "main", hosts = [local.spoke2_us_alb_fqdn, ] },
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
      instances   = [module.spoke2_us_alb_vm.self_link, ]
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
