
locals {
  site1_vpc_ipv6_cidr = module.site1_vpc.internal_ipv6_range
  site1_dns_main_ipv6 = module.site1_dns.internal_ipv6
  site1_vm_main_ipv6  = module.site1_vm.internal_ipv6
}

# network
#---------------------------------

module "site1_vpc" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v34.1.0"
  project_id = var.project_id_onprem
  name       = "${local.site1_prefix}vpc"
  subnets    = local.site1_subnets_list

  ipv6_config = {
    enable_ula_internal = true
  }
}

# nat
#---------------------------------

module "site1_nat" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v34.1.0"
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
    "${local.site1_prefix}allow-egress-all" = {
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
    ONPREM_LOCAL_RECORDS = local.onprem_local_records_site1
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts_site1
    FORWARD_ZONES        = local.onprem_forward_zones_site1
    TARGETS              = local.vm_script_targets
    ACCESS_CONTROL_PREFIXES = concat(
      local.netblocks.internal,
      ["127.0.0.0/8", "35.199.192.0/19", "fd00::/8", ]
    )
  }
  onprem_local_records_site1 = [
    { name = local.site1_vm_fqdn, rdata = local.site1_vm_addr, ttl = "300", type = "A" },
    { name = local.site2_vm_fqdn, rdata = local.site2_vm_addr, ttl = "300", type = "A" },
    { name = lower(local.site1_vm_fqdn), rdata = local.site1_vm_main_ipv6, ttl = "300", type = "AAAA" },
    { name = lower(local.site2_vm_fqdn), rdata = local.site2_vm_main_ipv6, ttl = "300", type = "AAAA" },
  ]
  # hosts redirected to psc endpoint
  onprem_redirected_hosts_site1 = [
    {
      class = "IN", ttl = "3600", type = "A", rdata = local.hub_psc_api_all_fr_addr
      hosts = [
        "storage.googleapis.com",
        "bigquery.googleapis.com",
        "${local.hub_eu_region}-aiplatform.googleapis.com",
        "${local.hub_us_region}-aiplatform.googleapis.com",
        "run.app",
      ]
    },
    # authoritative hosts
    { hosts = [local.hub_eu_psc_https_ctrl_run_dns], class = "IN", ttl = "3600", type = "A", rdata = local.hub_eu_ilb7_addr },
    { hosts = [local.hub_us_psc_https_ctrl_run_dns], class = "IN", ttl = "3600", type = "A", rdata = local.hub_us_ilb7_addr },
  ]
  onprem_forward_zones_site1 = [
    { zone = "${local.cloud_domain}.", targets = [local.hub_eu_ns_addr, ] },
    { zone = "${local.hub_psc_api_fr_name}.p.googleapis.com", targets = [local.hub_eu_ns_addr, ] },
    { zone = local.spoke1_reverse_zone, targets = [local.hub_eu_ns_addr, ] },
    { zone = local.spoke2_reverse_zone, targets = [local.hub_eu_ns_addr, ] },
    { zone = ".", targets = ["8.8.8.8", "8.8.4.4"] },
  ]
}

# unbound instance

module "site1_dns" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_onprem
  name       = "${local.site1_prefix}dns"
  zone       = "${local.site1_region}-b"
  tags       = [local.tag_dns, local.tag_ssh]

  network_interfaces = [{
    stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
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
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v34.1.0"
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
    "output/site1-unbound.sh" = local.site1_unbound_startup
  }
}

resource "local_file" "site1_files" {
  for_each = local.site1_files
  filename = each.key
  content  = each.value
}
