
# namespace
#---------------------------------

resource "google_service_directory_namespace" "hub_td" {
  provider     = google-beta
  project      = var.project_id_hub
  namespace_id = "${local.hub_prefix}td"
  location     = local.hub_eu_region
}

resource "google_service_directory_namespace" "hub_psc" {
  provider     = google-beta
  project      = var.project_id_hub
  namespace_id = "${local.hub_prefix}psc"
  location     = local.hub_eu_region
}

# network
#---------------------------------

module "hub_vpc" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v33.0.0"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}vpc"

  subnets             = local.hub_subnets_list
  subnets_private_nat = local.spoke1_subnets_private_nat_list
  subnets_proxy_only  = local.spoke1_subnets_proxy_only_list
  subnets_psc         = local.spoke1_subnets_psc_list

  psa_configs = [{
    ranges = {
      "${local.spoke1_prefix}hub-eu-psa-range1" = local.hub_eu_psa_range1
      "${local.spoke1_prefix}hub-eu-psa-range2" = local.hub_eu_psa_range2
    }
    export_routes  = true
    import_routes  = true
    peered_domains = ["gcp.example.com."]
  }]
}

# addresses
#---------------------------------

resource "google_compute_address" "hub_eu_main_addresses" {
  for_each     = local.hub_eu_main_addresses
  project      = var.project_id_hub
  name         = each.key
  subnetwork   = module.hub_vpc.subnet_ids["${local.hub_eu_region}/eu-main"]
  address_type = "INTERNAL"
  address      = each.value.addr
  region       = local.hub_eu_region
}

resource "google_compute_address" "hub_us_main_addresses" {
  for_each     = local.hub_us_main_addresses
  project      = var.project_id_hub
  name         = each.key
  subnetwork   = module.hub_vpc.subnet_ids["${local.hub_us_region}/us-main"]
  address_type = "INTERNAL"
  address      = each.value.addr
  region       = local.hub_us_region
}

# service networking connection
#---------------------------------

# vpc-sc config

# resource "google_service_networking_vpc_service_controls" "hub" {
#   provider   = google-beta
#   project    = var.project_id_hub
#   network    = google_compute_network.hub_vpc.name
#   service    = google_service_networking_connection.hub_eu_psa_ranges.service
#   enabled    = true
#   depends_on = [google_compute_network_peering_routes_config.hub_eu_psa_ranges]
# }

# nat
#---------------------------------

module "hub_nat_eu" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v33.0.0"
  project_id     = var.project_id_hub
  region         = local.hub_eu_region
  name           = "${local.hub_prefix}eu-nat"
  router_network = module.hub_vpc.self_link
  router_create  = true

  config_source_subnetworks = {
    primary_ranges_only = true
  }
}

module "hub_nat_us" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v33.0.0"
  project_id     = var.project_id_hub
  region         = local.hub_us_region
  name           = "${local.hub_prefix}us-nat"
  router_network = module.hub_vpc.self_link
  router_create  = true

  config_source_subnetworks = {
    primary_ranges_only = true
  }
}

# firewall
#---------------------------------

module "hub1_vpc_fw_policy" {
  source    = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-firewall-policy?ref=v33.0.0"
  name      = "${local.hub_prefix}vpc-fw-policy"
  parent_id = var.project_id_hub
  region    = "global"
  attachments = {
    hub-vpc = module.hub_vpc.self_link
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
    gfe = {
      priority = 1004
      match = {
        source_ranges  = local.netblocks.gfe
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
    }
  }
}

# custom dns
#---------------------------------

# eu

module "hub_eu_dns" {
  source     = "../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-dns"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_dns, local.tag_ssh]

  network_interfaces = [{
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
    addresses = {
      internal = local.hub_eu_ns_addr
    }
  }]
  service_account = {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.hub_unbound_config
}

# us

module "hub_us_dns" {
  source     = "../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}us-dns"
  zone       = "${local.hub_us_region}-b"
  tags       = [local.tag_dns, local.tag_ssh]

  network_interfaces = [{
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
    addresses = {
      internal = local.hub_us_ns_addr
    }
  }]
  service_account = {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.hub_unbound_config
}

# psc/api
#---------------------------------

# hub

resource "google_compute_global_address" "hub_psc_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_hub
  name         = local.hub_psc_api_fr_name
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = module.hub_vpc.self_link
  address      = local.hub_psc_api_fr_addr
}

resource "google_compute_global_forwarding_rule" "hub_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = local.hub_psc_api_fr_name
  target                = local.hub_psc_api_fr_target
  network               = module.hub_vpc.self_link
  ip_address            = google_compute_global_address.hub_psc_api_fr_addr.id
  load_balancing_scheme = ""
}

# dns policy
#---------------------------------

resource "google_dns_policy" "hub_dns_policy" {
  provider                  = google-beta
  project                   = var.project_id_hub
  name                      = "${local.hub_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = module.hub_vpc.self_link }
}

# dns response policy
#---------------------------------

resource "time_sleep" "hub_dns_forward_to_dns_wait" {
  create_duration = "120s"
  depends_on = [
    module.hub_eu_dns,
    module.hub_us_dns,
  ]
}

# rules - local

locals {
  hub_dns_rp_rules = {
    drp-rule-eu-psc-https-ctrl = { dns_name = "${local.hub_eu_psc_https_ctrl_run_dns}.", local_data = { A = { rrdatas = [local.hub_eu_ilb7_addr] } } }
    drp-rule-us-psc-https-ctrl = { dns_name = "${local.hub_us_psc_https_ctrl_run_dns}.", local_data = { A = { rrdatas = [local.hub_us_ilb7_addr] } } }
    drp-rule-runapp            = { dns_name = "*.run.app.", local_data = { A = { rrdatas = [local.hub_psc_api_fr_addr] } } }
    drp-rule-gcr               = { dns_name = "*.gcr.io.", local_data = { A = { rrdatas = [local.hub_psc_api_fr_addr] } } }
    drp-rule-apis              = { dns_name = "*.googleapis.com.", local_data = { A = { rrdatas = [local.hub_psc_api_fr_addr] } } }
    drp-rule-bypass-www        = { dns_name = "www.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-ouath2     = { dns_name = "oauth2.googleapis.com.", behavior = "bypassResponsePolicy" }
    drp-rule-bypass-psc        = { dns_name = "*.p.googleapis.com.", behavior = "bypassResponsePolicy" }
  }
}

# policy

module "dns-policy" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns-response-policy?ref=v33.0.0"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}drp"
  rules      = local.hub_dns_rp_rules
  networks = {
    hub = module.hub_vpc.self_link
  }
}

# cloud dns
#---------------------------------

# psc zone

module "hub_dns_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_hub
  type        = "private"
  name        = "${local.hub_prefix}psc"
  domain      = "${local.hub_psc_api_fr_name}.p.googleapis.com."
  description = "psc"
  client_networks = [
    module.hub_vpc.self_link,
  ]
  recordsets = {
    "A " = { ttl = 300, records = [local.hub_psc_api_fr_addr] }
  }
  depends_on = [time_sleep.hub_dns_forward_to_dns_wait]
}

# onprem zone

module "hub_dns_forward_to_onprem" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_hub
  type        = "forwarding"
  name        = "${local.hub_prefix}to-onprem"
  domain      = "${local.onprem_domain}."
  description = "local data"
  forwarders = {
    (local.hub_eu_ns_addr) = "private"
    (local.hub_us_ns_addr) = "private"
  }
  client_networks = [module.hub_vpc.self_link]
}

# local zone

module "hub_dns_private_zone" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_hub
  type        = "private"
  name        = "${local.hub_prefix}private"
  domain      = "${local.hub_domain}.${local.cloud_domain}."
  description = "local data"
  client_networks = [
    module.hub_vpc.self_link,
  ]
  recordsets = {
    "A ${local.hub_eu_ilb4_dns_prefix}" = { ttl = 300, records = [local.hub_eu_ilb4_addr] },
    "A ${local.hub_us_ilb4_dns_prefix}" = { ttl = 300, records = [local.hub_us_ilb4_addr] },
    "A ${local.hub_eu_ilb7_dns_prefix}" = { ttl = 300, records = [local.hub_eu_ilb7_addr] },
    "A ${local.hub_us_ilb7_dns_prefix}" = { ttl = 300, records = [local.hub_us_ilb7_addr] },
  }
}

# sd zone

module "hub_sd_td" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_hub
  type        = "service-directory"
  name        = "${local.hub_prefix}sd-td"
  domain      = "${local.hub_td_domain}."
  description = google_service_directory_namespace.hub_td.id
  client_networks = [
    module.hub_vpc.self_link,
  ]
  service_directory_namespace = google_service_directory_namespace.hub_td.id
}

module "hub_sd_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_hub
  type        = "service-directory"
  name        = "${local.hub_prefix}sd-psc"
  domain      = "${local.hub_psc_domain}."
  description = google_service_directory_namespace.hub_psc.id
  client_networks = [
    module.hub_vpc.self_link,
  ]
  service_directory_namespace = google_service_directory_namespace.hub_psc.id
}

# ilb4 - eu
#---------------------------------

# instance

resource "google_compute_instance" "hub_eu_ilb4_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-ilb4-vm"
  zone         = "${local.hub_eu_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = var.image_ubuntu
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# # instance group

# resource "google_compute_instance_group" "hub_eu_ilb4_ig" {
#   project   = var.project_id_hub
#   zone      = "${local.hub_eu_region}-b"
#   name      = "${local.hub_prefix}eu-ilb4-ig"
#   instances = [google_compute_instance.hub_eu_ilb4_vm.self_link]
#   named_port {
#     name = local.svc_web.name
#     port = local.svc_web.port
#   }
# }

# # ilb4

# module "hub_eu_ilb4" {
#   source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb?ref=v15.0.0"
#   project_id    = var.project_id_hub
#   region        = local.hub_eu_region
#   name          = "${local.hub_prefix}eu-ilb4"
#   service_label = "${local.hub_prefix}eu-ilb4"
#   network       = module.hub_vpc.self_link
#   subnetwork    = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
#   address       = local.hub_eu_ilb4_addr
#   backends = [{
#     failover       = false
#     group          = google_compute_instance_group.hub_eu_ilb4_ig.self_link
#     balancing_mode = "CONNECTION"
#   }]
#   health_check_config = {
#     type    = "http"
#     config  = {}
#     logging = true
#     check = {
#       port_specification = "USE_FIXED_PORT"
#       port               = local.svc_web.port
#       host               = local.uhc_config.host
#       request_path       = "/${local.uhc_config.request_path}"
#       response           = local.uhc_config.response
#     }
#   }
#   global_access = true
# }

# ilb4: hub-us
#---------------------------------

# instance

resource "google_compute_instance" "hub_us_ilb4_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}us-ilb4-vm"
  zone         = "${local.hub_us_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = var.image_ubuntu
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# # instance group

# resource "google_compute_instance_group" "hub_us_ilb4_ig" {
#   project   = var.project_id_hub
#   zone      = "${local.hub_us_region}-b"
#   name      = "${local.hub_prefix}us-ilb4-ig"
#   instances = [google_compute_instance.hub_us_ilb4_vm.self_link]
#   named_port {
#     name = local.svc_web.name
#     port = local.svc_web.port
#   }
# }

# # ilb4

# module "hub_us_ilb4" {
#   source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb?ref=v15.0.0"
#   project_id    = var.project_id_hub
#   region        = local.hub_us_region
#   name          = "${local.hub_prefix}us-ilb4"
#   service_label = "${local.hub_prefix}us-ilb4"
#   network       = module.hub_vpc.self_link
#   subnetwork    = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
#   address       = local.hub_us_ilb4_addr
#   backends = [{
#     failover       = false
#     group          = google_compute_instance_group.hub_us_ilb4_ig.self_link
#     balancing_mode = "CONNECTION"
#   }]
#   health_check_config = {
#     type    = "http"
#     config  = {}
#     logging = true
#     check = {
#       port_specification = "USE_FIXED_PORT"
#       port               = local.svc_web.port
#       host               = local.uhc_config.host
#       request_path       = "/${local.uhc_config.request_path}"
#       response           = local.uhc_config.response
#     }
#   }
#   global_access = true
# }

# ilb7: hub-eu
#---------------------------------

locals {
  hub_eu_ilb7_domains = [
    "${local.hub_eu_ilb7_dns_prefix}.${local.hub_domain}.${local.cloud_domain}",
    local.hub_eu_psc_https_ctrl_run_dns
  ]
}

# instance

resource "google_compute_instance" "hub_eu_ilb7_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-ilb7-vm"
  zone         = "${local.hub_eu_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = var.image_ubuntu
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# # ig

# resource "google_compute_instance_group" "hub_eu_ilb7_ig" {
#   project   = var.project_id_hub
#   zone      = "${local.hub_eu_region}-b"
#   name      = "${local.hub_prefix}eu-ilb7-ig"
#   instances = [google_compute_instance.hub_eu_ilb7_vm.self_link]
#   named_port {
#     name = local.svc_web.name
#     port = local.svc_web.port
#   }
# }

# # psc neg

# locals {
#   hub_eu_ilb7_psc_api_neg_name      = "${local.hub_prefix}eu-ilb7-psc-api-neg"
#   hub_eu_ilb7_psc_api_neg_self_link = "projects/${var.project_id_hub}/regions/${local.hub_eu_region}/networkEndpointGroups/${local.hub_eu_ilb7_psc_api_neg_name}"
#   hub_eu_ilb7_psc_api_neg_create = templatefile("../scripts/neg/psc/create.sh", {
#     PROJECT_ID     = var.project_id_hub
#     NETWORK        = module.hub_vpc.self_link
#     REGION         = local.hub_eu_region
#     NEG_NAME       = local.hub_eu_ilb7_psc_api_neg_name
#     TARGET_SERVICE = local.hub_eu_psc_https_ctrl_run_dns
#   })
#   hub_eu_ilb7_psc_api_neg_delete = templatefile("../scripts/neg/psc/delete.sh", {
#     PROJECT_ID = var.project_id_hub
#     REGION     = local.hub_eu_region
#     NEG_NAME   = local.hub_eu_ilb7_psc_api_neg_name
#   })
# }

# resource "null_resource" "hub_eu_ilb7_psc_api_neg" {
#   triggers = {
#     create = local.hub_eu_ilb7_psc_api_neg_create
#     delete = local.hub_eu_ilb7_psc_api_neg_delete
#   }
#   provisioner "local-exec" {
#     command = self.triggers.create
#   }
#   provisioner "local-exec" {
#     when    = destroy
#     command = self.triggers.delete
#   }
# }

# # backend

# locals {
#   hub_eu_ilb7_backend_services_mig = {
#     ("main") = {
#       port_name = local.svc_web.name
#       backends = [
#         {
#           group                 = google_compute_instance_group.hub_eu_ilb7_ig.self_link
#           balancing_mode        = "RATE"
#           max_rate_per_instance = 100
#           capacity_scaler       = 1.0
#         },
#       ]
#       health_check_config = {
#         config  = {}
#         logging = true
#         check = {
#           port_specification = "USE_SERVING_PORT"
#           host               = local.uhc_config.host
#           request_path       = "/${local.uhc_config.request_path}"
#           response           = local.uhc_config.response
#         }
#       }
#     }
#   }
#   hub_eu_ilb7_backend_services_psc_neg = {
#     ("api") = {
#       port = local.svc_web.port
#       backends = [
#         {
#           group           = local.hub_eu_ilb7_psc_api_neg_self_link
#           balancing_mode  = "UTILIZATION"
#           capacity_scaler = 1.0
#         },
#       ]
#       health_check_config = {
#         config  = {}
#         logging = true
#         check   = {}
#       }
#     }
#   }
#   hub_eu_ilb7_backend_services_neg = {}
# }

# module "hub_eu_ilb7_bes" {
#   depends_on               = [null_resource.hub_eu_ilb7_psc_api_neg]
#   source                   = "../modules/backend-region"
#   project_id               = var.project_id_hub
#   prefix                   = "${local.hub_prefix}eu-ilb7"
#   network                  = module.hub_vpc.self_link
#   region                   = local.hub_eu_region
#   backend_services_mig     = local.hub_eu_ilb7_backend_services_mig
#   backend_services_neg     = local.hub_eu_ilb7_backend_services_neg
#   backend_services_psc_neg = local.hub_eu_ilb7_backend_services_psc_neg
# }

# # url map

# resource "google_compute_region_url_map" "hub_eu_ilb7_url_map" {
#   provider        = google-beta
#   project         = var.project_id_hub
#   name            = "${local.hub_prefix}eu-ilb7-url-map"
#   region          = local.hub_eu_region
#   default_service = module.hub_eu_ilb7_bes.backend_service_mig["main"].id
#   host_rule {
#     path_matcher = "main"
#     hosts        = ["${local.hub_eu_ilb7_dns_prefix}.${local.hub_domain}.${local.cloud_domain}"]
#   }
#   host_rule {
#     path_matcher = "api"
#     hosts        = [local.hub_eu_psc_https_ctrl_run_dns]
#   }
#   path_matcher {
#     name            = "main"
#     default_service = module.hub_eu_ilb7_bes.backend_service_mig["main"].self_link
#   }
#   path_matcher {
#     name            = "api"
#     default_service = module.hub_eu_ilb7_bes.backend_service_psc_neg["api"].self_link
#   }
# }

# # frontend

# module "hub_eu_ilb7_frontend" {
#   source     = "../modules/int-lb-app-frontend"
#   project_id = var.project_id_hub
#   prefix     = "${local.hub_prefix}eu-ilb7"
#   network    = module.hub_vpc.self_link
#   subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
#   region     = local.hub_eu_region
#   url_map    = google_compute_region_url_map.hub_eu_ilb7_url_map.id
#   frontend = {
#     address = local.hub_eu_ilb7_addr
#     ssl     = { self_cert = true, domains = local.hub_eu_ilb7_domains }
#   }
# }

# ilb7: hub-us
#---------------------------------

locals {
  hub_us_ilb7_domains = [
    "${local.hub_us_ilb7_dns_prefix}.${local.hub_domain}.${local.cloud_domain}",
    local.hub_us_psc_https_ctrl_run_dns
  ]
}

# instance

resource "google_compute_instance" "hub_us_ilb7_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}us-ilb7-vm"
  zone         = "${local.hub_us_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = var.image_ubuntu
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# # ig

# resource "google_compute_instance_group" "hub_us_ilb7_ig" {
#   project   = var.project_id_hub
#   zone      = "${local.hub_us_region}-b"
#   name      = "${local.hub_prefix}us-ilb7-ig"
#   instances = [google_compute_instance.hub_us_ilb7_vm.self_link]
#   named_port {
#     name = local.svc_web.name
#     port = local.svc_web.port
#   }
# }

# # psc neg

# locals {
#   hub_us_ilb7_psc_neg_name      = "${local.hub_prefix}us-ilb7-psc-neg"
#   hub_us_ilb7_psc_neg_self_link = "projects/${var.project_id_hub}/regions/${local.hub_us_region}/networkEndpointGroups/${local.hub_us_ilb7_psc_neg_name}"
#   hub_us_ilb7_psc_neg_create = templatefile("../scripts/neg/psc/create.sh", {
#     PROJECT_ID     = var.project_id_hub
#     NETWORK        = module.hub_vpc.self_link
#     REGION         = local.hub_us_region
#     NEG_NAME       = local.hub_us_ilb7_psc_neg_name
#     TARGET_SERVICE = local.hub_us_psc_https_ctrl_run_dns
#   })
#   hub_us_ilb7_psc_neg_delete = templatefile("../scripts/neg/psc/delete.sh", {
#     PROJECT_ID = var.project_id_hub
#     REGION     = local.hub_us_region
#     NEG_NAME   = local.hub_us_ilb7_psc_neg_name
#   })
# }

# resource "null_resource" "hub_us_ilb7_psc_neg" {
#   triggers = {
#     create = local.hub_us_ilb7_psc_neg_create
#     delete = local.hub_us_ilb7_psc_neg_delete
#   }
#   provisioner "local-exec" {
#     command = self.triggers.create
#   }
#   provisioner "local-exec" {
#     when    = destroy
#     command = self.triggers.delete
#   }
# }

# # backend

# locals {
#   hub_us_ilb7_backend_services_mig = {
#     ("main") = {
#       port_name = local.svc_web.name
#       backends = [
#         {
#           group                 = google_compute_instance_group.hub_us_ilb7_ig.self_link
#           balancing_mode        = "RATE"
#           max_rate_per_instance = 100
#           capacity_scaler       = 1.0
#         },
#       ]
#       health_check_config = {
#         config  = {}
#         logging = true
#         check = {
#           port_specification = "USE_SERVING_PORT"
#           host               = local.uhc_config.host
#           request_path       = "/${local.uhc_config.request_path}"
#           response           = local.uhc_config.response
#         }
#       }
#     }
#   }
#   hub_us_ilb7_backend_services_psc_neg = {
#     ("api") = {
#       port = local.svc_web.port
#       backends = [
#         {
#           group           = local.hub_us_ilb7_psc_neg_self_link
#           balancing_mode  = "UTILIZATION"
#           capacity_scaler = 1.0
#         },
#       ]
#       health_check_config = {
#         config  = {}
#         logging = true
#         check   = {}
#       }
#     }
#   }
#   hub_us_ilb7_backend_services_neg = {}
# }

# module "hub_us_ilb7_bes" {
#   depends_on               = [null_resource.hub_us_ilb7_psc_neg]
#   source                   = "../modules/backend-region"
#   project_id               = var.project_id_hub
#   prefix                   = "${local.hub_prefix}us-ilb7"
#   network                  = module.hub_vpc.self_link
#   region                   = local.hub_us_region
#   backend_services_mig     = local.hub_us_ilb7_backend_services_mig
#   backend_services_neg     = local.hub_us_ilb7_backend_services_neg
#   backend_services_psc_neg = local.hub_us_ilb7_backend_services_psc_neg
# }

# # url map

# resource "google_compute_region_url_map" "hub_us_ilb7_url_map" {
#   provider        = google-beta
#   project         = var.project_id_hub
#   name            = "${local.hub_prefix}us-ilb7-url-map"
#   region          = local.hub_us_region
#   default_service = module.hub_us_ilb7_bes.backend_service_mig["main"].id
#   host_rule {
#     path_matcher = "main"
#     hosts        = ["${local.hub_us_ilb7_dns_prefix}.${local.hub_domain}.${local.cloud_domain}"]
#   }
#   host_rule {
#     path_matcher = "api"
#     hosts        = [local.hub_us_psc_https_ctrl_run_dns]
#   }
#   path_matcher {
#     name            = "main"
#     default_service = module.hub_us_ilb7_bes.backend_service_mig["main"].self_link
#   }
#   path_matcher {
#     name            = "api"
#     default_service = module.hub_us_ilb7_bes.backend_service_psc_neg["api"].self_link
#   }
# }

# # frontend

# module "hub_us_ilb7_frontend" {
#   source     = "../modules/int-lb-app-frontend"
#   project_id = var.project_id_hub
#   prefix     = "${local.hub_prefix}us-ilb7"
#   network    = module.hub_vpc.self_link
#   subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
#   region     = local.hub_us_region
#   url_map    = google_compute_region_url_map.hub_us_ilb7_url_map.id
#   frontend = {
#     address = local.hub_us_ilb7_addr
#     ssl     = { self_cert = true, domains = local.hub_us_ilb7_domains }
#   }
# }

####################################################
# output files
####################################################

locals {
  hub_files = {
    "output/hub-unbound.sh" = local.hub_unbound_config
  }
}

resource "local_file" "hub_files" {
  for_each = local.hub_files
  filename = each.key
  content  = each.value
}

