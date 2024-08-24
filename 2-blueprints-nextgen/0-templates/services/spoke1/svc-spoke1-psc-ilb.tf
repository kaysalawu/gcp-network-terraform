
# psc/ilb producer
#---------------------------------

# instance

resource "google_compute_instance" "spoke1_eu_vm_psc_prod" {
  project      = var.project_id_host
  name         = "${local.spoke1_prefix}eu-vm-psc-prod"
  zone         = "${local.spoke1_eu_region}-b"
  machine_type = "e2-small"
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = var.image_ubuntu
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
    network    = google_compute_network.spoke1_vpc.self_link
    subnetwork = local.spoke1_eu_subnet1.self_link
  }
  service_account { scopes = ["cloud-platform"] }
  metadata_startup_script = local.vm_startup
}

# instance group

resource "google_compute_instance_group" "spoke1_eu_ig_psc_prod" {
  project   = var.project_id_host
  zone      = "${local.spoke1_eu_region}-b"
  name      = "${local.spoke1_prefix}eu-ig-psc-prod"
  instances = [google_compute_instance.spoke1_eu_vm_psc_prod.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# psc-ilb4 (regional)

module "spoke1_eu_ilb4_psc_prod" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb?ref=v15.0.0"
  project_id    = var.project_id_host
  region        = local.spoke1_eu_region
  name          = "${local.spoke1_prefix}eu-ilb4-psc-prod"
  service_label = "${local.spoke1_prefix}eu-ilb4-psc-prod"
  network       = google_compute_network.spoke1_vpc.self_link
  subnetwork    = local.spoke1_eu_subnet1.self_link
  backends = [{
    failover       = false
    group          = google_compute_instance_group.spoke1_eu_ig_psc_prod.self_link
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
  global_access = false
}

# config files

resource "local_file" "spoke1_eu_vm_psc_prod" {
  content  = google_compute_instance.spoke1_eu_vm_psc_prod.metadata_startup_script
  filename = "output/central/${local.spoke1_prefix}eu-vm-psc-prod.sh"
}

# service attachment

resource "google_compute_service_attachment" "spoke1_eu_svc_attach" {
  provider    = google-beta
  project     = var.project_id_host
  name        = "${local.spoke1_prefix}eu-svc-attach"
  region      = local.spoke1_eu_region
  description = "spoke1 eu psc service"

  enable_proxy_protocol = false
  connection_preference = "ACCEPT_AUTOMATIC"
  nat_subnets           = [local.spoke1_eu_psc_nat_subnet1.name]
  target_service        = module.spoke1_eu_ilb4_psc_prod.forwarding_rule_id
}

# psc/ilb consumer
#---------------------------------

# endpoint address

resource "google_compute_address" "hub_eu_psc_spoke1_addr" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-psc-spoke1-addr"
  region       = local.hub_eu_region
  subnetwork   = local.hub_eu_subnet1.self_link
  address_type = "INTERNAL"
}
# forwarding rule

resource "google_compute_forwarding_rule" "hub_eu_psc_spoke1_fr" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = "${local.hub_prefix}eu-psc-spoke1-fr"
  region                = local.hub_eu_region
  target                = google_compute_service_attachment.spoke1_eu_svc_attach.id
  network               = google_compute_network.hub_vpc.self_link
  ip_address            = google_compute_address.hub_eu_psc_spoke1_addr.id
  load_balancing_scheme = ""
}

# service directory

resource "google_service_directory_service" "hub_eu_psc_spoke1_dns" {
  provider   = google-beta
  service_id = local.hub_eu_psc_spoke1_dns
  namespace  = google_service_directory_namespace.hub_psc.id
  metadata = {
    service = "spoke1-eu-svc-attach"
    region  = local.spoke1_eu_region
  }
}

resource "google_service_directory_endpoint" "hub_eu_psc_spoke1_addr" {
  provider    = google-beta
  endpoint_id = "${local.hub_prefix}eu-psc-spoke1-addr"
  service     = google_service_directory_service.hub_eu_psc_spoke1_dns.id
  address     = google_compute_address.hub_eu_psc_spoke1_addr.address
  port        = local.svc_web.port
}

# spoke2 - psc/ilb consumer
#---------------------------------

# endpoint address

resource "google_compute_address" "spoke2_eu_psc_spoke1_addr" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}eu-psc-spoke1-addr"
  region       = local.spoke2_eu_region
  subnetwork   = local.spoke2_eu_subnet1.self_link
  address_type = "INTERNAL"
}

# forwarding rule

resource "google_compute_forwarding_rule" "spoke2_eu_psc_spoke1_fr" {
  provider              = google-beta
  project               = var.project_id_spoke2
  name                  = "${local.spoke2_prefix}eu-psc-spoke1-fr"
  region                = local.spoke2_eu_region
  target                = google_compute_service_attachment.spoke1_eu_svc_attach.id
  network               = google_compute_network.spoke2_vpc.self_link
  ip_address            = google_compute_address.spoke2_eu_psc_spoke1_addr.id
  load_balancing_scheme = ""
}

# service directory

resource "google_service_directory_service" "spoke2_eu_psc_spoke1_dns" {
  provider   = google-beta
  service_id = local.spoke2_eu_psc_spoke1_dns
  namespace  = google_service_directory_namespace.spoke2_psc.id
  metadata = {
    service = "spoke1-eu-svc-attach"
    region  = local.spoke1_eu_region
  }
}

resource "google_service_directory_endpoint" "spoke2_eu_psc_spoke1_addr" {
  provider    = google-beta
  endpoint_id = "${local.spoke2_prefix}eu-psc-spoke1-addr"
  service     = google_service_directory_service.spoke2_eu_psc_spoke1_dns.id
  address     = google_compute_address.spoke2_eu_psc_spoke1_addr.address
  port        = local.svc_web.port
}
