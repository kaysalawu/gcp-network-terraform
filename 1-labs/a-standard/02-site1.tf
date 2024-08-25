
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

module "site1_vpc_fw_policy" {
  source    = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-firewall-policy?ref=v33.0.0"
  name      = "${local.site1_prefix}vpc-fw-policy"
  parent_id = var.project_id_onprem
  region    = "global"
  attachments = {
    hub-vpc = module.site1_vpc.self_link
  }
  egress_rules = {
    smtp = {
      priority = 900
      match = {
        destination_ranges = ["0.0.0.0/0"]
        layer4_configs     = [{ protocol = "tcp", ports = ["25"] }]
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
    ssh = {
      priority       = 1001
      enable_logging = true
      match = {
        source_ranges  = ["0.0.0.0/0", ]
        layer4_configs = [{ protocol = "tcp", ports = ["22"] }]
      }
    }
    vpn = {
      priority = 1002
      match = {
        source_ranges = ["0.0.0.0/0", ]
        layer4_configs = [
          { protocol = "udp", ports = ["500", "4500", ] },
          { protocol = "esp", ports = [] }
        ]
      }
    }
    dns = {
      priority = 1003
      match = {
        source_ranges  = local.netblocks.dns
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
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

resource "google_compute_instance" "site1_dns" {
  project      = var.project_id_onprem
  name         = "${local.site1_prefix}dns"
  machine_type = var.machine_type
  zone         = "${local.site1_region}-b"
  tags         = [local.tag_dns, local.tag_ssh]
  boot_disk {
    initialize_params {
      image = var.image_ubuntu
      type  = var.disk_type
      size  = var.disk_size
    }
  }
  network_interface {
    network    = module.site1_vpc.self_link
    subnetwork = module.site1_vpc.subnet_self_links["${local.site1_region}/main"]
    network_ip = local.site1_ns_addr
  }
  service_account {
    email  = module.site1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.site1_unbound_startup
  allow_stopping_for_update = true
}

# cloud dns
#---------------------------------

resource "time_sleep" "site1_dns_forward_to_dns_wait_120s" {
  create_duration = "120s"
  depends_on      = [google_compute_instance.site1_dns]
}

module "site1_dns_forward_to_dns" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_onprem
  type        = "forwarding"
  name        = "${local.site1_prefix}to-dns"
  description = "forward all dns queries to custom resolvers"
  domain      = "."
  client_networks = [
    module.site1_vpc.self_link
  ]
  forwarders = {
    (local.site1_ns_addr) = "private"
    (local.site2_ns_addr) = "private"
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
    addresses = {
      internal = local.site1_vm_addr
    }
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
    "output/site1-unbound-startup.sh" = local.site1_unbound_startup
  }
}

resource "local_file" "site1_files" {
  for_each = local.site1_files
  filename = each.key
  content  = each.value
}
