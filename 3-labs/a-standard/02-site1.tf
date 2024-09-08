
# network
#---------------------------------

module "site1_vpc" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v33.0.0"
  project_id = var.project_id_onprem
  name       = "${local.site1_prefix}vpc"
  subnets    = local.site1_subnets_list
}

# nat
#---------------------------------

module "site1_nat" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v33.0.0"
  project_id     = var.project_id_onprem
  region         = local.site1_region
  name           = "${local.site1_prefix}nat"
  router_network = module.site1_vpc.self_link
  router_create  = true

  config_source_subnetworks = {
    all = false
    subnetworks = [for s in local.site1_subnets_list : {
      self_link        = module.site1_vpc.subnet_self_links["${s.region}/${s.name}"]
      all_ranges       = false
      primary_range    = true
      secondary_ranges = contains(keys(try(s.secondary_ip_ranges, {})), "pods") ? ["pods"] : null
    }]
  }
}

# firewall
#---------------------------------

# policy

module "site1_vpc_fw_policy" {
  source    = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-firewall-policy?ref=v33.0.0"
  name      = "${local.site1_prefix}vpc-fw-policy"
  parent_id = var.project_id_onprem
  region    = "global"
  attachments = {
    site1-vpc = module.site1_vpc.self_link
  }
  egress_rules = {
    smtp = {
      priority = 900
      match = {
        destination_ranges = ["0.0.0.0/0"]
        layer4_configs     = [{ protocol = "tcp", ports = ["25"] }]
      }
    }
    all = {
      priority = 910
      action   = "allow"
      match = {
        destination_ranges = ["0.0.0.0/0"]
        layer4_configs     = [{ protocol = "all", ports = [] }]
      }
    }
  }
  ingress_rules = {
    internal = {
      priority = 1000
      match = {
        source_ranges  = local.netblocks.internal
        layer4_configs = [{ protocol = "all" }]
      }
    }
    dns = {
      priority = 1100
      match = {
        source_ranges  = local.netblocks.dns
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
    }
    ssh = {
      priority       = 1200
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
      priority = 1400
      match = {
        source_ranges = ["0.0.0.0/0", ]
        layer4_configs = [
          { protocol = "udp", ports = ["500", "4500", ] },
          { protocol = "esp", ports = [] }
        ]
      }
    }
    gfe = {
      priority = 1500
      match = {
        source_ranges  = local.netblocks.gfe
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
    }
  }
}

# vpc

module "site1_vpc_firewall" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall?ref=v33.0.0"
  project_id = var.project_id_onprem
  network    = module.site1_vpc.name

  egress_rules = {
    "${local.site1_prefix}allow-egress-smtp" = {
      priority           = 900
      description        = "block smtp"
      destination_ranges = ["0.0.0.0/0", ]
      rules              = [{ protocol = "tcp", ports = [25, ] }]
    }
    "${local.site1_prefix}allow-egress-all" = {
      priority           = 1000
      deny               = false
      description        = "allow egress"
      destination_ranges = ["0.0.0.0/0", ]
      rules              = [{ protocol = "all", ports = [] }]
    }
  }
  ingress_rules = {
    "${local.site1_prefix}allow-ingress-internal" = {
      priority      = 1000
      description   = "allow internal"
      source_ranges = local.netblocks.internal
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.site1_prefix}allow-ingress-dns" = {
      priority      = 1100
      description   = "allow dns"
      source_ranges = local.netblocks.dns
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.site1_prefix}allow-ingress-ssh" = {
      priority       = 1200
      description    = "allow ingress ssh"
      source_ranges  = ["0.0.0.0/0"]
      targets        = [local.tag_router]
      rules          = [{ protocol = "tcp", ports = [22] }]
      enable_logging = {}
    }
    "${local.site1_prefix}allow-ingress-iap" = {
      priority       = 1300
      description    = "allow ingress iap"
      source_ranges  = local.netblocks.iap
      targets        = [local.tag_router]
      rules          = [{ protocol = "all", ports = [] }]
      enable_logging = {}
    }
    "${local.site1_prefix}allow-ingress-dns-proxy" = {
      priority      = 1400
      description   = "allow dns egress proxy"
      source_ranges = local.netblocks.dns
      targets       = [local.tag_dns]
      rules         = [{ protocol = "all", ports = [] }]
    }
  }
}

# custom dns
#---------------------------------

# unbound startup

locals {
  site1_unbound_startup = templatefile("../../scripts/unbound/unbound.sh", local.site1_dns_vars)
  site1_dns_vars = {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    FORWARD_ZONES        = local.onprem_forward_zones
    TARGETS              = local.vm_script_targets
    ACCESS_CONTROL_PREFIXES = concat(
      local.netblocks.internal,
      ["127.0.0.0/8", "35.199.192.0/19", "fd00::/8", ]
    )
  }
}

# unbound instance

module "site1_dns" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_onprem
  name       = "${local.site1_prefix}dns"
  zone       = "${local.site1_region}-b"
  tags       = [local.tag_dns, local.tag_ssh]

  network_interfaces = [{
    network    = module.site1_vpc.self_link
    subnetwork = module.site1_vpc.subnet_self_links["${local.site1_region}/main"]
    addresses  = { internal = local.site1_ns_addr }
  }]
  service_account = {
    email  = module.site1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.site1_unbound_startup
}

# cloud dns
#---------------------------------

resource "time_sleep" "site1_dns_forward_to_dns_wait_120s" {
  create_duration = "120s"
  depends_on      = [module.site1_dns, ]
}

module "site1_dns_forward_to_dns" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v33.0.0"
  project_id  = var.project_id_onprem
  name        = "${local.site1_prefix}to-dns"
  description = "forward all dns queries to custom resolvers"
  zone_config = {
    domain = "."
    forwarding = {
      client_networks = [module.site1_vpc.self_link, ]
      forwarders      = { (local.site1_ns_addr) = "private" }
    }
  }
  depends_on = [time_sleep.site1_dns_forward_to_dns_wait_120s]
}

# workload
#---------------------------------

# app

module "site1_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_onprem
  name       = "${local.site1_prefix}vm"
  zone       = "${local.site1_region}-b"
  tags       = [local.tag_ssh, local.tag_http]

  network_interfaces = [{
    network    = module.site1_vpc.self_link
    subnetwork = module.site1_vpc.subnet_self_links["${local.site1_region}/main"]
    addresses  = { internal = local.site1_vm_addr }
  }]
  service_account = {
    email  = module.site1_sa.email
    scopes = ["cloud-platform"]
  }
  # metadata_startup_script = module.vm_cloud_init.cloud_config
  metadata = {
    user-data = module.vm_cloud_init.cloud_config
  }
}

####################################################
# output files
####################################################

locals {
  site1_files = {
    "output/site1-unbound.sh" = local.site1_unbound_startup
  }
}

resource "local_file" "site1_files" {
  for_each = local.site1_files
  filename = each.key
  content  = each.value
}
