
# psc4 producer
#---------------------------------

# instance

resource "google_compute_instance" "spoke1_eu_vm_psc4_prod" {
  project      = var.project_id_spoke1
  name         = "${local.spoke1_prefix}eu-vm-psc4-prod"
  zone         = "${local.spoke1_eu_region}-b"
  machine_type = "e2-micro"
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

resource "google_compute_instance_group" "spoke1_eu_ig_psc4_prod" {
  project   = var.project_id_spoke1
  zone      = "${local.spoke1_eu_region}-b"
  name      = "${local.spoke1_prefix}eu-ig-psc4-prod"
  instances = [google_compute_instance.spoke1_eu_vm_psc4_prod.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# psc4 (regional)

module "spoke1_eu_psc4_prod" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb?ref=v15.0.0"
  project_id    = var.project_id_spoke1
  region        = local.spoke1_eu_region
  name          = "${local.spoke1_prefix}eu-psc4-prod"
  service_label = "${local.spoke1_prefix}eu-psc4-prod"
  network       = google_compute_network.spoke1_vpc.self_link
  subnetwork    = local.spoke1_eu_subnet1.self_link
  backends = [{
    failover       = false
    group          = google_compute_instance_group.spoke1_eu_ig_psc4_prod.self_link
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

resource "local_file" "spoke1_eu_vm_psc4_prod" {
  content  = google_compute_instance.spoke1_eu_vm_psc4_prod.metadata_startup_script
  filename = "output/central/${local.spoke1_prefix}eu-vm-psc4-prod.sh"
}

# service attachment

resource "google_compute_service_attachment" "spoke1_eu_svc_attach" {
  provider    = google-beta
  project     = var.project_id_spoke1
  name        = "${local.spoke1_prefix}eu-svc-attach"
  region      = local.spoke1_eu_region
  description = "hub eu psc4 service"

  enable_proxy_protocol = false
  connection_preference = "ACCEPT_AUTOMATIC"
  nat_subnets           = [local.spoke1_eu_psc4_nat]
  target_service        = module.spoke1_eu_psc4_prod.forwarding_rule_id
}
