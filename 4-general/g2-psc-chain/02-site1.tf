
####################################################
# network
####################################################

module "site1_vpc" {
  # source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v34.1.0"
  source     = "../../modules/net-vpc"
  project_id = var.project_id_onprem
  name       = "${local.site1_prefix}vpc"
  subnets    = local.site1_subnets_list

  ipv6_config = {
    enable_ula_internal = true
  }
}

####################################################
# nat
####################################################

module "site1_nat" {
  source         = # "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v34.1.0"
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

####################################################
# firewall
####################################################

# policy

module "site1_vpc_fw_policy" {
  source    = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-firewall-policy?ref=v34.1.0"
  name      = "${local.site1_prefix}vpc-fw-policy"
  parent_id = var.project_id_onprem
  region    = "global"
  attachments = {
    site1-vpc = module.site1_vpc.self_link
  }
  egress_rules  = local.firewall_policies.site_egress_rules
  ingress_rules = local.firewall_policies.site_ingress_rules
}

# vpc

module "site1_vpc_firewall" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall?ref=v34.1.0"
  project_id = var.project_id_onprem
  network    = module.site1_vpc.name

  egress_rules = {
    # ipv4
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
    # ipv6
    "${local.site1_prefix}allow-egress-smtp-ipv6" = {
      priority           = 901
      description        = "block smtp"
      destination_ranges = ["::/0", ]
      rules              = [{ protocol = "tcp", ports = [25, ] }]
    }
    "${local.site1_prefix}allow-egress-all-ipv6" = {
      priority           = 1001
      deny               = false
      description        = "allow egress"
      destination_ranges = ["::/0", ]
      rules              = [{ protocol = "all", ports = [] }]
    }
  }
  ingress_rules = {
    # ipv4
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
    # ipv6
    "${local.site1_prefix}allow-ingress-internal-ipv6" = {
      priority      = 1000
      description   = "allow internal"
      source_ranges = local.netblocks_ipv6.internal
      rules         = [{ protocol = "all", ports = [] }]
    }
    "${local.site1_prefix}allow-ingress-ssh-ipv6" = {
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
# cloud dns
####################################################

# local zone

module "site1_dns_private_zone" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v34.1.0"
  project_id  = var.project_id_onprem
  name        = "${local.site1_prefix}private"
  description = "site1 network attached"
  zone_config = {
    domain = "${local.site1_domain}.${local.onprem_domain}."
    private = {
      client_networks = [
        module.site1_vpc.self_link,
        module.hub_vpc.self_link,
        module.site1_vpc.self_link,
      ]
    }
  }
  recordsets = {
    "A ${local.site1_ep_hub_eu_psc_ilb_prefix}" = { ttl = 300, records = [local.site1_ep_hub_eu_psc_ilb_addr] },
    "A ${local.site1_ep_hub_eu_psc_nlb_prefix}" = { ttl = 300, records = [local.site1_ep_hub_eu_psc_nlb_addr] },
    "A ${local.site1_ep_hub_eu_psc_alb_prefix}" = { ttl = 300, records = [local.site1_ep_hub_eu_psc_alb_addr] },
  }
}

####################################################
# workload
####################################################

# app

module "site1_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_onprem
  name       = "${local.site1_prefix}vm"
  zone       = "${local.site1_region}-b"
  tags       = [local.tag_ssh, local.tag_http]

  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
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
  }
}

resource "local_file" "site1_files" {
  for_each = local.site1_files
  filename = each.key
  content  = each.value
}
