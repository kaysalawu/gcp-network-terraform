

# common
#-------------------------------

# public dns zone

data "google_dns_managed_zone" "hub_nlb_public_zone" {
  project = var.project_id_hub
  name    = "global-public-cloudtuple"
}

locals {
  hub_nlb_host = "network.${data.google_dns_managed_zone.hub_nlb_public_zone.dns_name}"
  /*hub_nlb_fw_rule_allowed_sources = concat(
    ["${data.external.hub_nlb_local_nat_ipv4.result.ip}", ],
    [for x in google_compute_address.hub_eu_nlb_flood4_vm : x.address],
  )*/
  hub_nlb_fw_rule_allowed_sources = ["0.0.0.0/0"]
}

# addresses
#-------------------------------

locals {
  hub_nlb_flood4_count = 3
}

# local nat

data "external" "hub_nlb_local_nat_ipv4" {
  program = ["sh", "../scripts/general/external-ipv4.sh"]
}

data "external" "hub_nlb_local_nat_ipv6" {
  program = ["sh", "../scripts/general/external-ipv6.sh"]
}

# frontend

resource "google_compute_address" "hub_eu_nlb_frontend" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-nlb-frontend"
  region  = local.hub_eu_region
}

# traffic gen

resource "google_compute_address" "hub_eu_nlb_flood4_vm" {
  count   = local.hub_nlb_flood4_count
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-nlb-flood4-vm${count.index}"
  region  = local.hub_eu_region
}

# traffic gen
#-------------------------------

locals {
  hub_eu_nlb_flood4_vm_startup = templatefile("../scripts/startup/armor/flood4.sh", {
    TARGET_VIP  = google_compute_address.hub_eu_nlb_frontend.address
    TARGET_PORT = local.svc_juice.port
  })
}

# layer4 flood traffic gen

module "hub_eu_nlb_flood4_vm" {
  count         = local.hub_nlb_flood4_count
  source        = "../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-nlb-flood4-vm${count.index}"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-standard-4"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_eu_nlb_flood4_vm[count.index].address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_eu_nlb_flood4_vm_startup
}

# workload
#-------------------------------

locals {
  hub_eu_nlb_juice_vm_config = templatefile("../scripts/startup/juice.yaml", {
    APP_NAME  = "${local.hub_prefix}juice-shop"
    APP_IMAGE = "bkimminich/juice-shop"
  })
  hub_eu_nlb_juice_vm_cos = templatefile("../scripts/startup/armor/juice-nlb.sh", {
    NLB_VIP = google_compute_address.hub_eu_nlb_frontend.address
    VM_IP   = module.hub_eu_nlb_juice_vm.internal_ip
    PORT    = local.svc_juice.port
    VCPU    = 2
  })
}

module "hub_eu_nlb_juice_vm" {
  source        = "../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-nlb-juice-vm"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, local.tag_gfe, "allow-external", ]
  instance_type = "e2-standard-4"
  boot_disk = {
    image = var.image_cos
    type  = var.disk_type
    size  = var.disk_size
  }
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses  = null
    nat        = true
    alias_ips  = null
  }]
  service_account        = module.hub_sa.email
  service_account_scopes = ["cloud-platform"]
  metadata = {
    gce-container-declaration = local.hub_eu_nlb_juice_vm_config
    google-logging-enabled    = true
    google-monitoring-enabled = true
  }
}

resource "local_file" "hub_eu_nlb_juice_vm_cos" {
  content  = local.hub_eu_nlb_juice_vm_cos
  filename = "config/hub/armor/eu-nlb-juice-vm.sh"
}

# firewall

resource "google_compute_firewall" "hub_nlb_allow_external_juice" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}allow-external-juice"
  network = google_compute_network.hub_vpc.self_link
  allow {
    protocol = "tcp"
    ports    = [local.svc_juice.port, ]
  }
  allow {
    protocol = "udp"
    ports    = [local.svc_juice.port, ]
  }
  source_ranges = local.hub_nlb_fw_rule_allowed_sources
  target_tags   = ["allow-external", ]
}

# instance group
#-------------------------------

# eu

resource "google_compute_instance_group" "hub_eu_nlb_juice_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_eu_region}-b"
  name      = "${local.hub_prefix}eu-nlb-juice-ig"
  instances = [module.hub_eu_nlb_juice_vm.self_link, ]
  named_port {
    name = local.svc_juice.name
    port = local.svc_juice.port
  }
}

# nlb
#-------------------------------

# tcp

module "hub_eu_nlb_tcp" {
  source     = "../modules/network-lb"
  project_id = var.project_id_hub
  region     = local.hub_eu_region
  name       = "${local.hub_prefix}eu-nlb-tcp"
  address    = google_compute_address.hub_eu_nlb_frontend.address
  protocol   = "TCP"
  ports      = [local.svc_juice.port, ]
  backends = [{
    group          = google_compute_instance_group.hub_eu_nlb_juice_ig.self_link
    balancing_mode = "CONNECTION"
    failover       = false
  }]
  health_check_config = {
    type    = "http"
    config  = {}
    logging = true
    check   = { port = local.svc_juice.port }
  }
}

# udp

module "hub_eu_nlb_udp" {
  source     = "../modules/network-lb"
  project_id = var.project_id_hub
  region     = local.hub_eu_region
  name       = "${local.hub_prefix}eu-nlb-udp"
  address    = google_compute_address.hub_eu_nlb_frontend.address
  ports      = [local.svc_juice.port]
  protocol   = "UDP"
  backends = [{
    group          = google_compute_instance_group.hub_eu_nlb_juice_ig.self_link
    balancing_mode = "CONNECTION"
    failover       = false
  }]
  health_check_config = {
    type    = "http"
    config  = {}
    logging = true
    check   = { port = local.svc_juice.port }
  }
}

# dns
#-------------------------------

resource "google_dns_record_set" "hub_eu_nlb_dns" {
  project      = var.project_id_hub
  managed_zone = data.google_dns_managed_zone.hub_nlb_public_zone.name
  name         = local.hub_nlb_host
  type         = "A"
  ttl          = 300
  rrdatas      = [module.hub_eu_nlb_tcp.forwarding_rule.ip_address]
}

# policy
#----------------------------------------------------

locals {
  hub_nlb_ca_policy_create = templatefile("../scripts/armor/network/policy/create.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = "${local.hub_prefix}nlb-ca-policy"
    REGION      = local.hub_us_region
  })
  hub_nlb_ca_policy_delete = templatefile("../scripts/armor/network/policy/delete.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = "${local.hub_prefix}nlb-ca-policy"
    REGION      = local.hub_us_region
  })
}

resource "null_resource" "hub_us_nlb_policy" {
  triggers = {
    create = local.hub_nlb_ca_policy_create
    delete = local.hub_nlb_ca_policy_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# service
#----------------------------------------------------

locals {
  hub_nlb_ca_service_create = templatefile("../scripts/armor/network/service/create.sh", {
    PROJECT_ID   = var.project_id_hub
    POLICY_NAME  = "${local.hub_prefix}nlb-ca-policy"
    SERVICE_NAME = "${local.hub_prefix}nlb-ca-service"
    REGION       = local.hub_us_region
  })
  hub_nlb_ca_service_delete = templatefile("../scripts/armor/network/service/delete.sh", {
    PROJECT_ID   = var.project_id_hub
    POLICY_NAME  = "${local.hub_prefix}nlb-ca-policy"
    SERVICE_NAME = "${local.hub_prefix}nlb-ca-service"
    REGION       = local.hub_us_region
  })
}

resource "null_resource" "hub_nlb_ca_service" {
  depends_on = [null_resource.hub_us_nlb_policy, ]
  triggers = {
    create = local.hub_nlb_ca_service_create
    delete = local.hub_nlb_ca_service_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}
