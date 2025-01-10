
# common
#----------------------------------------------------

# public dns zone

data "google_dns_managed_zone" "hub_xlb7_public_zone" {
  project = var.project_id_hub
  name    = "global-public-cloudtuple"
}

locals {
  hub_xlb7_host_secure                 = "secure.${data.google_dns_managed_zone.hub_xlb7_public_zone.dns_name}"
  hub_xlb7_host_unsecure               = "unsecure.${data.google_dns_managed_zone.hub_xlb7_public_zone.dns_name}"
  hub_xlb7_host_secure_juice           = "secure-juice.${data.google_dns_managed_zone.hub_xlb7_public_zone.dns_name}"
  hub_xlb7_host_unsecure_juice         = "unsecure-juice.${data.google_dns_managed_zone.hub_xlb7_public_zone.dns_name}"
  hub_xlb7_host_secure_trimmed         = trimsuffix(local.hub_xlb7_host_secure, ".")
  hub_xlb7_host_unsecure_trimmed       = trimsuffix(local.hub_xlb7_host_unsecure, ".")
  hub_xlb7_host_secure_juice_trimmed   = trimsuffix(local.hub_xlb7_host_secure_juice, ".")
  hub_xlb7_host_unsecure_juice_trimmed = trimsuffix(local.hub_xlb7_host_unsecure_juice, ".")
  hub_xlb7_domains = [
    local.hub_xlb7_host_secure,
    local.hub_xlb7_host_unsecure,
    local.hub_xlb7_host_secure_juice,
    local.hub_xlb7_host_unsecure_juice
  ]
  hub_xlb7_domains_trimmed = [
    local.hub_xlb7_host_secure_trimmed,
    local.hub_xlb7_host_unsecure_trimmed,
    local.hub_xlb7_host_secure_juice_trimmed,
    local.hub_xlb7_host_unsecure_juice_trimmed
  ]
}

# addresses
#----------------------------------------------------

locals {
  hub_xlb7_flood4_count = 1
  hub_xlb7_flood7_count = 1
}

# local nat

data "external" "hub_xlb7_local_nat_ipv4" {
  program = ["sh", "../../scripts/general/external-ipv4.sh"]
}

data "external" "hub_xlb7_local_nat_ipv6" {
  program = ["sh", "../../scripts/general/external-ipv6.sh"]
}

# frontend

resource "google_compute_global_address" "hub_xlb7_frontend" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}ext-lb-app-frontend"
}

# traffic gen

resource "google_compute_address" "hub_eu_xlb7_flood4_vm" {
  count   = local.hub_xlb7_flood4_count
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-xlb7-flood4-vm${count.index}"
  region  = local.hub_eu_region
}

resource "google_compute_address" "hub_eu_xlb7_flood7_vm" {
  count   = local.hub_xlb7_flood7_count
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-xlb7-flood7-vm${count.index}"
  region  = local.hub_eu_region
}

resource "google_compute_address" "hub_eu_xlb7_baseline_vm" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-xlb7-baseline-vm"
  region  = local.hub_eu_region
}

resource "google_compute_address" "hub_eu_xlb7_denied_vm" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-xlb7-denied-vm"
  region  = local.hub_eu_region
}

# traffic gen
#----------------------------------------------------

locals {
  hub_eu_xlb7_flood4_vm_startup = templatefile("../../scripts/startup/armor/flood4.sh", {
    TARGET_VIP  = google_compute_global_address.hub_xlb7_frontend.address
    TARGET_PORT = 443
  })
  hub_eu_xlb7_flood7_vm_startup = templatefile("../../scripts/startup/armor/flood7.sh", {
    TARGET_URL = local.hub_xlb7_target_url
  })
  hub_baseline_vm_startup = templatefile("../../scripts/startup/armor/baseline.sh", {
    TARGET_URL = local.hub_xlb7_target_url
  })
  hub_denied_vm_startup = templatefile("../../scripts/startup/armor/denied.sh", {
    TARGET_URL = local.hub_xlb7_target_url
  })
  hub_xlb7_target_url = "https://${local.hub_xlb7_host_secure_trimmed}/"
}

# layer4 flood traffic gen

module "hub_eu_xlb7_flood4_vm" {
  count         = local.hub_xlb7_flood4_count
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-xlb7-flood4-vm${count.index}"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-standard-4"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_eu_xlb7_flood4_vm[count.index].address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_eu_xlb7_flood4_vm_startup
}

# flood7 alert traffic gen

module "hub_eu_xlb7_flood7_vm" {
  count         = local.hub_xlb7_flood7_count
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-xlb7-flood7-vm${count.index}"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-standard-2"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_eu_xlb7_flood7_vm[count.index].address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_eu_xlb7_flood7_vm_startup
}

# baseline traffic gen

module "hub_eu_baseline_vm" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-baseline-vm"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-standard-2"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_eu_xlb7_baseline_vm.address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_baseline_vm_startup
}

# denied traffic gen

module "hub_eu_denied_vm" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-denied-vm"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-medium"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_eu_xlb7_denied_vm.address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_denied_vm_startup
}

# workload
#----------------------------------------------------

locals {
  hub_xlb7_juice_cos_config = templatefile("../../scripts/startup/juice.yaml", {
    APP_NAME  = "${local.hub_prefix}juice-shop"
    APP_IMAGE = "bkimminich/juice-shop"
  })
  hub_xlb7_vm_cos = templatefile("../../scripts/startup/armor/juice-xlb7.sh", {
    VCPU = 2
  })
}

# eu

module "hub_eu_xlb7_juice_vm" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-xlb7-juice-vm"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, local.tag_gfe, "allow-flood4", ]
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
    gce-container-declaration = local.hub_xlb7_juice_cos_config
    google-logging-enabled    = true
    google-monitoring-enabled = true
  }
}

resource "local_file" "hub_eu_xlb7_juice_vm" {
  content  = local.hub_xlb7_vm_cos
  filename = "config/hub/armor/eu-xlb7-juice-vm.sh"
}

module "hub_eu_xlb7_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-xlb7-vm"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe, "allow-flood4", "mirror", ]
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses  = null
    nat        = true
    alias_ips  = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.vm_startup
}

# us

module "hub_us_xlb7_vm" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}us-xlb7-vm"
  zone          = "${local.hub_us_region}-b"
  tags          = [local.tag_ssh, local.tag_gfe, "allow-flood4", ]
  instance_type = "e2-standard-4"
  boot_disk = {
    image = var.image_ubuntu
    type  = var.disk_type
    size  = var.disk_size
  }
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    addresses  = null
    nat        = true
    alias_ips  = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.vm_startup
}

# firewall

resource "google_compute_firewall" "hub_xlb7_allow_ddos_flood4" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}xlb7-allow-ddos-flood4"
  network = google_compute_network.hub_vpc.self_link
  allow {
    protocol = "tcp"
    ports    = [local.svc_juice.port, local.svc_web.port, ]
  }
  source_ranges = [for x in google_compute_address.hub_eu_xlb7_flood4_vm : x.address]
  target_tags   = ["allow-flood4", ]
}

# hybrid gfe proxy instances
#----------------------------------------------------

# eu

locals {
  hub_eu_xlb7_hc_proxy_startup = templatefile("../../scripts/startup/proxy_hc.sh", {
    GFE_RANGES = local.netblocks.gfe
    DNAT_IP    = local.site1_vm_addr
  })
}

module "hub_eu_xlb7_hc_proxy" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-xlb7-hc-proxy"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      internal = local.hub_eu_hybrid_hc_proxy_addr
      external = null
    }
    nat       = false
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_eu_xlb7_hc_proxy_startup
}

# us

locals {
  hub_us_xlb7_hc_proxy_startup = templatefile("../../scripts/startup/proxy_hc.sh", {
    GFE_RANGES = local.netblocks.gfe
    DNAT_IP    = local.site2_vm_addr
  })
}

module "hub_us_xlb7_hc_proxy" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}us-xlb7-hc-proxy"
  zone       = "${local.hub_us_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    addresses = {
      internal = local.hub_us_hybrid_hc_proxy_addr
      external = null
    }
    nat       = false
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_us_xlb7_hc_proxy_startup
}

# instance group
#----------------------------------------------------

# eu

resource "google_compute_instance_group" "hub_eu_xlb7_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_eu_region}-b"
  name      = "${local.hub_prefix}eu-xlb7-ig"
  instances = [module.hub_eu_xlb7_vm.self_link, ]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

resource "google_compute_instance_group" "hub_eu_xlb7_juice_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_eu_region}-b"
  name      = "${local.hub_prefix}eu-xlb7-juice-ig"
  instances = [module.hub_eu_xlb7_juice_vm.self_link, ]
  named_port {
    name = local.svc_juice.name
    port = local.svc_juice.port
  }
}

# us

resource "google_compute_instance_group" "hub_us_xlb7_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_us_region}-b"
  name      = "${local.hub_prefix}us-xlb7-ig"
  instances = [module.hub_us_xlb7_vm.self_link, ]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# neg
#----------------------------------------------------

# eu

resource "google_compute_network_endpoint_group" "hub_eu_xlb7_hybrid_neg" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = "${local.hub_prefix}eu-xlb7-hybrid-neg"
  network               = google_compute_network.hub_vpc.id
  default_port          = local.svc_web.port
  zone                  = "${local.hub_us_region}-b"
  network_endpoint_type = "NON_GCP_PRIVATE_IP_PORT"
}

resource "google_compute_network_endpoint" "hub_eu_xlb7_hybrid_neg_onprem" {
  provider               = google-beta
  project                = var.project_id_hub
  zone                   = "${local.hub_us_region}-b"
  network_endpoint_group = google_compute_network_endpoint_group.hub_eu_xlb7_hybrid_neg.name
  ip_address             = local.hub_eu_hybrid_hc_proxy_addr
  port                   = google_compute_network_endpoint_group.hub_eu_xlb7_hybrid_neg.default_port
}

# us

resource "google_compute_network_endpoint_group" "hub_us_xlb7_hybrid_neg" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = "${local.hub_prefix}us-xlb7-hybrid-neg"
  network               = google_compute_network.hub_vpc.id
  default_port          = local.svc_web.port
  zone                  = "${local.hub_us_region}-b"
  network_endpoint_type = "NON_GCP_PRIVATE_IP_PORT"
}

resource "google_compute_network_endpoint" "hub_us_xlb7_hybrid_neg_onprem" {
  provider               = google-beta
  project                = var.project_id_hub
  zone                   = "${local.hub_us_region}-b"
  network_endpoint_group = google_compute_network_endpoint_group.hub_us_xlb7_hybrid_neg.name
  ip_address             = local.hub_us_hybrid_hc_proxy_addr
  port                   = google_compute_network_endpoint_group.hub_us_xlb7_hybrid_neg.default_port
}

# security policy - backend
#----------------------------------------------------

# create sec policy to allow all traffic
# rules will be configured after

locals {
  hub_sec_rule_ip_ranges_allowed_list = concat(
    [
      "${data.external.hub_xlb7_local_nat_ipv4.result.ip}",
      google_compute_address.hub_eu_xlb7_denied_vm.address,
      google_compute_address.hub_eu_xlb7_baseline_vm.address,
    ],
    [for x in google_compute_address.hub_eu_xlb7_flood4_vm : x.address],
    [for x in google_compute_address.hub_eu_xlb7_flood7_vm : x.address],
  )
  hub_sec_rule_ip_ranges_allowed_string = join(",", local.hub_sec_rule_ip_ranges_allowed_list)
}

locals {
  hub_xlb7_sec_rule_sqli_excluded_crs = join(",", [
    "'owasp-crs-v030001-id942421-sqli'",
    "'owasp-crs-v030001-id942200-sqli'",
    "'owasp-crs-v030001-id942260-sqli'",
    "'owasp-crs-v030001-id942340-sqli'",
    "'owasp-crs-v030001-id942430-sqli'",
    "'owasp-crs-v030001-id942431-sqli'",
    "'owasp-crs-v030001-id942432-sqli'",
    "'owasp-crs-v030001-id942420-sqli'",
    "'owasp-crs-v030001-id942440-sqli'",
    "'owasp-crs-v030001-id942450-sqli'",
  ])
  hub_xlb7_sec_rule_preconfigured_sqli_tuned = "evaluatePreconfiguredExpr('sqli-stable',[${local.hub_xlb7_sec_rule_sqli_excluded_crs}])"
  hub_xlb7_sec_rule_custom_hacker            = "origin.region_code == 'US' && request.headers['Referer'].contains('hacker')"
}

locals {
  hub_xlb7_backend_sec_rules_expr = {
    ("lfi")      = { preview = false, priority = 10, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('lfi-stable')" }
    ("rce")      = { preview = false, priority = 20, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('rce-stable')" }
    ("scanners") = { preview = false, priority = 30, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('scannerdetection-stable')" }
    ("protocol") = { preview = false, priority = 40, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('protocolattack-stable')" }
    ("session")  = { preview = false, priority = 50, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('sessionfixation-stable')" }
    ("sqli")     = { preview = false, priority = 60, action = "deny(403)", ip = false, expression = local.hub_xlb7_sec_rule_preconfigured_sqli_tuned }
    ("hacker")   = { preview = true, priority = 70, action = "deny(403)", ip = false, expression = local.hub_xlb7_sec_rule_custom_hacker }
    ("xss")      = { preview = true, priority = 80, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('xss-stable')" }
  }
  hub_xlb7_backend_sec_rules_versioned_expr = {
    ("ranges")  = { preview = false, priority = 90, action = "allow", ip = true, src_ip_ranges = local.hub_sec_rule_ip_ranges_allowed_list }
    ("default") = { preview = false, priority = 2147483647, action = "deny(403)", src_ip_ranges = ["*"] }
  }
}

resource "google_compute_security_policy" "hub_xlb7_backend_sec_policy" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}xlb7-backend-sec-policy"
  description = "CLOUD_ARMOR"
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }
  dynamic "rule" {
    for_each = local.hub_xlb7_backend_sec_rules_versioned_expr
    iterator = rule
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.key
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = rule.value.src_ip_ranges
        }
      }
    }
  }
  dynamic "rule" {
    for_each = local.hub_xlb7_backend_sec_rules_expr
    iterator = rule
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.key
      match {
        expr {
          expression = rule.value.expression
        }
      }
    }
  }
}

# backend
#----------------------------------------------------

# backend services

locals {
  hub_xlb7_backend_services_mig = {
    ("secure") = {
      port_name       = local.svc_web.name
      enable_cdn      = true
      security_policy = google_compute_security_policy.hub_xlb7_backend_sec_policy.name
      backends = [
        { group = google_compute_instance_group.hub_eu_xlb7_ig.self_link },
        { group = google_compute_instance_group.hub_us_xlb7_ig.self_link }
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port_specification = "USE_SERVING_PORT" }
      }
    }
    ("unsecure") = {
      port_name       = local.svc_web.name
      security_policy = null
      enable_cdn      = false
      backends = [
        { group = google_compute_instance_group.hub_eu_xlb7_ig.self_link },
        { group = google_compute_instance_group.hub_us_xlb7_ig.self_link }
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port_specification = "USE_SERVING_PORT" }
      }
    }
  }
  hub_xlb7_backend_services_mig_juice = {
    ("secure-juice") = {
      port_name       = local.svc_juice.name
      enable_cdn      = true
      security_policy = google_compute_security_policy.hub_xlb7_backend_sec_policy.name
      backends = [
        { group = google_compute_instance_group.hub_eu_xlb7_juice_ig.self_link },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port_specification = "USE_SERVING_PORT" }
      }
    }
    ("unsecure-juice") = {
      port_name       = local.svc_juice.name
      security_policy = null
      enable_cdn      = false
      backends = [
        { group = google_compute_instance_group.hub_eu_xlb7_juice_ig.self_link },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port_specification = "USE_SERVING_PORT" }
      }
    }
  }
  hub_xlb7_backend_services_neg = {
    ("secure") = {
      port            = local.svc_web.port
      security_policy = google_compute_security_policy.hub_xlb7_backend_sec_policy.name
      enable_cdn      = true
      backends = [
        { group = google_compute_network_endpoint_group.hub_eu_xlb7_hybrid_neg.id },
        { group = google_compute_network_endpoint_group.hub_us_xlb7_hybrid_neg.id }
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port = local.svc_web.port }
      }
    }
  }
}

module "hub_xlb7_backend_service" {
  source                   = "../../modules/backend-global"
  project_id               = var.project_id_hub
  prefix                   = "${local.hub_prefix}xlb7"
  network                  = google_compute_network.hub_vpc.self_link
  backend_services_mig     = local.hub_xlb7_backend_services_mig
  backend_services_neg     = local.hub_xlb7_backend_services_neg
  backend_services_psc_neg = {}
}

module "hub_xlb7_backend_service_juice" {
  source                   = "../../modules/backend-global"
  project_id               = var.project_id_hub
  prefix                   = "${local.hub_prefix}xlb7-juice"
  network                  = google_compute_network.hub_vpc.self_link
  backend_services_mig     = local.hub_xlb7_backend_services_mig_juice
  backend_services_neg     = {}
  backend_services_psc_neg = {}
}

# backend bucket

module "hub_gcs_ca" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v15.0.0"
  project_id    = var.project_id_hub
  prefix        = ""
  name          = "${local.hub_prefix}gcs-ca"
  location      = local.hub_eu_region
  storage_class = "STANDARD"
  iam           = { "roles/storage.objectViewer" = ["allUsers"] }
}

resource "google_storage_bucket_object" "hub_gcs_ca_file" {
  name    = "error.txt"
  bucket  = module.hub_gcs_ca.name
  content = "ERROR !!!"
}

resource "google_compute_backend_bucket" "hub_xlb7_bachend_bucket" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}backend-bucket"
  bucket_name = module.hub_gcs_ca.name
  enable_cdn  = true
}

# url map
#----------------------------------------------------

resource "google_compute_url_map" "hub_xlb7_url_map" {
  provider        = google-beta
  project         = var.project_id_hub
  name            = "${local.hub_prefix}xlb7-url-map"
  default_service = module.hub_xlb7_backend_service.backend_service_mig["secure"].self_link
  host_rule {
    path_matcher = "secure"
    hosts        = [local.hub_xlb7_host_secure_trimmed]
  }
  host_rule {
    path_matcher = "unsecure"
    hosts        = [local.hub_xlb7_host_unsecure_trimmed]
  }
  host_rule {
    path_matcher = "secure-juice"
    hosts        = [local.hub_xlb7_host_secure_juice_trimmed]
  }
  host_rule {
    path_matcher = "unsecure-juice"
    hosts        = [local.hub_xlb7_host_unsecure_juice_trimmed]
  }
  path_matcher {
    name = "secure"
    route_rules {
      priority = 1
      match_rules {
        prefix_match = "/onprem"
      }
      route_action {
        url_rewrite {
          path_prefix_rewrite = "/"
        }
      }
      service = module.hub_xlb7_backend_service.backend_service_neg["secure"].self_link
    }
    default_service = module.hub_xlb7_backend_service.backend_service_mig["secure"].self_link
  }
  path_matcher {
    name            = "unsecure"
    default_service = module.hub_xlb7_backend_service.backend_service_mig["unsecure"].self_link
  }
  path_matcher {
    name            = "secure-juice"
    default_service = module.hub_xlb7_backend_service_juice.backend_service_mig["secure-juice"].self_link
  }
  path_matcher {
    name            = "unsecure-juice"
    default_service = module.hub_xlb7_backend_service_juice.backend_service_mig["unsecure-juice"].self_link
  }
}

# frontend
#----------------------------------------------------

module "hub_xlb7_frontend" {
  source     = "../../modules/ext-lb-app-frontend"
  project_id = var.project_id_hub
  prefix     = "${local.hub_prefix}xlb7"
  network    = google_compute_network.hub_vpc.self_link
  address    = google_compute_global_address.hub_xlb7_frontend.address
  url_map    = google_compute_url_map.hub_xlb7_url_map.name
  frontend = {
    regional = { enable = false, region = local.hub_eu_region }
    ssl      = { self_cert = true, domains = local.hub_xlb7_domains_trimmed }
  }
}

# dns
#----------------------------------------------------

resource "google_dns_record_set" "hub_xlb7_frontend_dns" {
  for_each     = toset(local.hub_xlb7_domains)
  project      = var.project_id_hub
  managed_zone = data.google_dns_managed_zone.hub_xlb7_public_zone.name
  name         = each.value
  type         = "A"
  ttl          = 300
  rrdatas      = [module.hub_xlb7_frontend.forwarding_rule.ip_address]
}
/*
# security policy - edge
#----------------------------------------------------

# create sec policy to allow all traffic
# rules will be configured after

locals {
  hub_xlb7_edge_sec_policy = "${local.hub_prefix}xlb7-edge-sec-policy"
  hub_xlb7_edge_sec_policy_create = templatefile("../../scripts/armor/edge/policy/create.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
    POLICY_TYPE = "CLOUD_ARMOR_EDGE"
  })
  hub_xlb7_edge_sec_policy_delete = templatefile("../../scripts/armor/edge/policy/delete.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
  })
}

resource "null_resource" "hub_xlb7_edge_sec_policy" {
  triggers = {
    create = local.hub_xlb7_edge_sec_policy_create
    delete = local.hub_xlb7_edge_sec_policy_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# security policy rules - edge
#----------------------------------------------------

# null_resource script to:
# 1) deny all ip ranges
# 2) allow selected ip ranges
# 3) in the future add custom rules when available for edge policy

locals {
  _hub_sec_rule_ip_ranges_allowed_list = join(
    ",", [for s in local.hub_sec_rule_ip_ranges_allowed_list : format("%q", s)]
  )
}
/*
locals {
  hub_xlb7_edge_sec_rules = {
    ("ranges") = { preview = true, priority = 100, action = "allow", ip = true, src_ip_ranges = local._hub_sec_rule_ip_ranges_allowed_list }
  }
  hub_xlb7_edge_sec_backends = [
    module.hub_xlb7_backend_service.backend_service_mig["secure"].name,
    module.hub_xlb7_backend_service.backend_service_neg["secure"].name,
    module.hub_xlb7_backend_service_juice.backend_service_mig["secure-juice"].name,
  ]
  hub_xlb7_edge_sec_rules_create = templatefile("../../scripts/armor/edge/rules/create.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
    RULES       = local.hub_xlb7_edge_sec_rules
    BACKENDS    = local.hub_xlb7_edge_sec_backends
    ENABLE      = true
  })
  hub_xlb7_edge_sec_rules_delete = templatefile("../../scripts/armor/edge/rules/delete.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
    RULES       = local.hub_xlb7_edge_sec_rules
    BACKENDS    = local.hub_xlb7_edge_sec_backends
    ENABLE      = true
  })
}

resource "null_resource" "hub_xlb7_edge_sec_rules" {
  depends_on = [null_resource.hub_xlb7_edge_sec_policy]
  triggers = {
    create = local.hub_xlb7_edge_sec_rules_create
    delete = local.hub_xlb7_edge_sec_rules_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}*/
