
# namespace
#---------------------------------

resource "google_service_directory_namespace" "spoke2_td" {
  provider     = google-beta
  project      = var.project_id_spoke2
  namespace_id = "${local.spoke2_prefix}td"
  location     = local.spoke2_us_region
}

resource "google_service_directory_namespace" "spoke2_psc" {
  provider     = google-beta
  project      = var.project_id_spoke2
  namespace_id = "${local.spoke2_prefix}psc"
  location     = local.spoke2_us_region
}

# cloud dns
#---------------------------------
/*
# onprem zone

module "spoke2_dns_peering_to_hub_to_onprem" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id      = var.project_id_spoke2
  type            = "peering"
  name            = "${local.spoke2_prefix}to-hub-to-onprem"
  domain          = "${local.onprem_domain}."
  description     = "peering to hub for onprem"
  client_networks = [google_compute_network.hub_int_vpc.self_link, ]
  peer_network    = google_compute_network.hub_vpc.self_link
}*/

# local zone

module "spoke2_dns_private_zone" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke2
  type        = "private"
  name        = "${local.spoke2_prefix}private"
  domain      = "${local.spoke2_domain}.${local.cloud_domain}."
  description = "local data"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.hub_mgt_vpc.self_link,
    google_compute_network.hub_int_vpc.self_link,
  ]
  recordsets = {
    "A ${local.spoke2_eu_ilb4_dns}" = { type = "A", ttl = 300, records = [local.spoke2_eu_ilb4_addr] },
    "A ${local.spoke2_us_ilb4_dns}" = { type = "A", ttl = 300, records = [local.spoke2_us_ilb4_addr] },
    "A ${local.spoke2_eu_ilb7_dns}" = { type = "A", ttl = 300, records = [local.spoke2_eu_ilb7_addr] },
    "A ${local.spoke2_us_ilb7_dns}" = { type = "A", ttl = 300, records = [local.spoke2_us_ilb7_addr] },
  }
}

# dns routing

locals {
  spoke2_dns_rr1 = "${local.spoke2_eu_region}=${local.spoke2_eu_td_envoy_bridge_ilb4_addr}"
  spoke2_dns_rr2 = "${local.spoke2_us_region}=${local.spoke2_us_td_envoy_bridge_ilb4_addr}"
  spoke2_dns_routing_data = {
    ("${local.spoke2_td_envoy_bridge_ilb4_dns}.${module.spoke2_dns_private_zone.domain}") = {
      zone        = module.spoke2_dns_private_zone.name,
      policy_type = "GEO", ttl = 300, type = "A",
      policy_data = "${local.spoke2_dns_rr1};${local.spoke2_dns_rr2}"
    }
  }
  spoke2_dns_routing_create = templatefile("scripts/dns/record-create.sh", {
    PROJECT = var.project_id_spoke2
    RECORDS = local.spoke2_dns_routing_data
  })
  spoke2_dns_routing_delete = templatefile("scripts/dns/record-delete.sh", {
    PROJECT = var.project_id_spoke2
    RECORDS = local.spoke2_dns_routing_data
  })
}

resource "null_resource" "spoke2_dns_routing" {
  triggers = {
    create = local.spoke2_dns_routing_create
    delete = local.spoke2_dns_routing_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# ilb4: us
#---------------------------------

# instance

resource "google_compute_instance" "spoke2_us_ilb4_vm" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}us-ilb4-vm"
  zone         = "${local.spoke2_us_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe, local.tag_hub_int_us_nva_ilb4]
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_int_vpc.self_link
    subnetwork = local.spoke2_us_subnet1.self_link
  }
  service_account {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

resource "local_file" "spoke2_us_ilb4_vm" {
  content  = google_compute_instance.spoke2_us_ilb4_vm.metadata_startup_script
  filename = "_config/spoke2/${local.spoke2_prefix}us-ilb4-vm.sh"
}

# instance group

resource "google_compute_instance_group" "spoke2_us_ilb4_ig" {
  project   = var.project_id_spoke2
  zone      = "${local.spoke2_us_region}-b"
  name      = "${local.spoke2_prefix}us-ilb4-ig"
  instances = [google_compute_instance.spoke2_us_ilb4_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

module "spoke2_us_ilb4" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb?ref=v15.0.0"
  project_id    = var.project_id_spoke2
  region        = local.spoke2_us_region
  name          = "${local.spoke2_prefix}us-ilb4"
  service_label = "${local.spoke2_prefix}us-ilb4"
  network       = google_compute_network.hub_int_vpc.self_link
  subnetwork    = local.spoke2_us_subnet1.self_link
  address       = local.spoke2_us_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.spoke2_us_ilb4_ig.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type    = "http"
    config  = {}
    logging = true
    check = {
      port_specification = "USE_FIXED_PORT"
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
    }
  }
  global_access = true
}

# service attachment
/*
resource "google_compute_service_attachment" "spoke2_us_producer_svc_attach" {
  provider    = google-beta
  project     = var.project_id_spoke2
  name        = "${local.spoke2_prefix}us-producer-svc-attach"
  region      = local.spoke2_us_region
  description = "spoke2 us psc4 producer service"

  enable_proxy_protocol = false
  connection_preference = "ACCEPT_AUTOMATIC"
  nat_subnets           = [local.spoke2_us_psc_producer_nat_subnet1.name]
  target_service        = module.spoke2_us_ilb4.forwarding_rule_id
}*/

# ilb7: spoke2-us
#---------------------------------

# domains

locals {
  spoke2_us_ilb7_domains = [
    "${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}",
    local.spoke2_us_psc_https_ctrl_run_dns
  ]
}

# instance

resource "google_compute_instance" "spoke2_us_ilb7_vm" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}us-ilb7-vm"
  zone         = "${local.spoke2_us_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe, local.tag_hub_int_us_nva_ilb4]
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_int_vpc.self_link
    subnetwork = local.spoke2_us_subnet1.self_link
  }
  service_account {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

resource "local_file" "spoke2_us_ilb7_vm" {
  content  = google_compute_instance.spoke2_us_ilb7_vm.metadata_startup_script
  filename = "_config/spoke2/${local.spoke2_prefix}us-ilb7-vm.sh"
}

# instance group

resource "google_compute_instance_group" "spoke2_us_ilb7_ig" {
  project   = var.project_id_spoke2
  zone      = "${local.spoke2_us_region}-b"
  name      = "${local.spoke2_prefix}us-ilb7-ig"
  instances = [google_compute_instance.spoke2_us_ilb7_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# psc neg

locals {
  spoke2_us_ilb7_psc_api_neg_name      = "${local.spoke2_prefix}us-ilb7-psc-api-neg"
  spoke2_us_ilb7_psc_api_neg_self_link = "projects/${var.project_id_spoke2}/regions/${local.spoke2_us_region}/networkEndpointGroups/${local.spoke2_us_ilb7_psc_api_neg_name}"
  spoke2_us_ilb7_psc_api_neg_create = templatefile("scripts/neg/psc/create.sh", {
    PROJECT_ID     = var.project_id_spoke2
    NETWORK        = google_compute_network.hub_int_vpc.self_link
    REGION         = local.spoke2_us_region
    NEG_NAME       = local.spoke2_us_ilb7_psc_api_neg_name
    TARGET_SERVICE = local.spoke2_us_psc_https_ctrl_run_dns
  })
  spoke2_us_ilb7_psc_api_neg_delete = templatefile("scripts/neg/psc/delete.sh", {
    PROJECT_ID = var.project_id_spoke2
    REGION     = local.spoke2_us_region
    NEG_NAME   = local.spoke2_us_ilb7_psc_api_neg_name
  })
}

resource "null_resource" "spoke2_us_ilb7_psc_api_neg" {
  triggers = {
    create = local.spoke2_us_ilb7_psc_api_neg_create
    delete = local.spoke2_us_ilb7_psc_api_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# backend

locals {
  spoke2_us_ilb7_backend_services_mig = {
    ("main") = {
      port_name = local.svc_web.name
      backends = [
        {
          group                 = google_compute_instance_group.spoke2_us_ilb7_ig.self_link
          balancing_mode        = "RATE"
          max_rate_per_instance = 100
          capacity_scaler       = 1.0
        },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check = {
          port_specification = "USE_SERVING_PORT"
          host               = local.uhc_config.host
          request_path       = "/${local.uhc_config.request_path}"
          response           = local.uhc_config.response
        }
      }
    }
  }
  spoke2_us_ilb7_backend_services_psc_neg = {
    ("api") = {
      port = local.svc_web.port
      backends = [
        {
          group           = local.spoke2_us_ilb7_psc_api_neg_self_link
          balancing_mode  = "UTILIZATION"
          capacity_scaler = 1.0
        },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = {}
      }
    }
  }
  spoke2_us_ilb7_backend_services_neg = {}
}

# backend services

module "spoke2_us_ilb7_bes" {
  depends_on               = [null_resource.spoke2_us_ilb7_psc_api_neg]
  source                   = "../../modules/backend-region"
  project_id               = var.project_id_spoke2
  prefix                   = "${local.spoke2_prefix}us-ilb7"
  network                  = google_compute_network.hub_int_vpc.self_link
  region                   = local.spoke2_us_region
  backend_services_mig     = local.spoke2_us_ilb7_backend_services_mig
  backend_services_neg     = local.spoke2_us_ilb7_backend_services_neg
  backend_services_psc_neg = local.spoke2_us_ilb7_backend_services_psc_neg
}

# url map

resource "google_compute_region_url_map" "spoke2_us_ilb7_url_map" {
  provider        = google-beta
  project         = var.project_id_spoke2
  name            = "${local.spoke2_prefix}us-ilb7-url-map"
  region          = local.spoke2_us_region
  default_service = module.spoke2_us_ilb7_bes.backend_service_mig["main"].id
  host_rule {
    path_matcher = "main"
    hosts        = ["${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}"]
  }
  host_rule {
    path_matcher = "api"
    hosts        = [local.spoke2_us_psc_https_ctrl_run_dns]
  }
  path_matcher {
    name            = "main"
    default_service = module.spoke2_us_ilb7_bes.backend_service_mig["main"].self_link
  }
  path_matcher {
    name            = "api"
    default_service = module.spoke2_us_ilb7_bes.backend_service_psc_neg["api"].self_link
  }
}

# frontend

module "spoke2_us_ilb7_frontend" {
  source           = "../../modules/ilb7-frontend"
  project_id       = var.project_id_spoke2
  prefix           = "${local.spoke2_prefix}us-ilb7"
  network          = google_compute_network.hub_int_vpc.self_link
  subnetwork       = local.spoke2_us_subnet1.self_link
  proxy_subnetwork = [local.spoke2_us_subnet3]
  region           = local.spoke2_us_region
  url_map          = google_compute_region_url_map.spoke2_us_ilb7_url_map.id
  frontend = {
    address = local.spoke2_us_ilb7_addr
    ssl     = { self_cert = true, domains = local.spoke2_us_ilb7_domains }
  }
}

# instances
#---------------------------------

resource "google_compute_instance" "spoke2_eu_test_vm" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}eu-test-vm"
  zone         = "${local.spoke2_eu_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_int_vpc.self_link
    subnetwork = local.spoke2_eu_subnet1.self_link
  }
  service_account {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

resource "local_file" "spoke2_eu_test_vm" {
  content  = google_compute_instance.spoke2_eu_test_vm.metadata_startup_script
  filename = "_config/spoke2/${local.spoke2_prefix}eu-test-vm.sh"
}
