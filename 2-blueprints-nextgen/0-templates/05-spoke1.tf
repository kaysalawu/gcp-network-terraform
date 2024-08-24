
# namespace
#---------------------------------

resource "google_service_directory_namespace" "spoke1_td" {
  provider     = google-beta
  project      = var.project_id_spoke1
  namespace_id = "${local.spoke1_prefix}td"
  location     = local.spoke1_eu_region
}

resource "google_service_directory_namespace" "spoke1_psc" {
  provider     = google-beta
  project      = var.project_id_spoke1
  namespace_id = "${local.spoke1_prefix}psc"
  location     = local.spoke1_eu_region
}

# dns policy
#---------------------------------

resource "google_dns_policy" "spoke1_dns_policy" {
  provider                  = google-beta
  project                   = var.project_id_spoke1
  name                      = "${local.spoke1_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = google_compute_network.spoke1_vpc.self_link }
}

# dns response policy
#---------------------------------

# policy

locals {
  spoke1_dns_rp_create = templatefile("../scripts/dns/policy-create.sh", {
    PROJECT     = var.project_id_spoke1
    RP_NAME     = "${local.spoke1_prefix}dns-rp"
    NETWORKS    = join(",", [google_compute_network.spoke1_vpc.self_link, ])
    DESCRIPTION = "dns repsonse policy"
  })
  spoke1_dns_rp_delete = templatefile("../scripts/dns/policy-delete.sh", {
    PROJECT = var.project_id_spoke1
    RP_NAME = "${local.spoke1_prefix}dns-rp"
  })
}

resource "null_resource" "spoke1_dns_rp" {
  triggers = {
    create = local.spoke1_dns_rp_create
    delete = local.spoke1_dns_rp_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# rules local data

locals {
  spoke1_dns_rp_rules_local = {
    ("${local.spoke1_prefix}dns-rp-rule-eu-psc-https-ctrl") = {
      dns_name   = "${local.spoke1_eu_psc_https_ctrl_run_dns}."
      local_data = "name=${local.spoke1_eu_psc_https_ctrl_run_dns}.,type=A,ttl=300,rrdatas=${local.spoke1_eu_ilb7_addr}"
    }
    ("${local.spoke1_prefix}dns-rp-rule-us-psc-https-ctrl") = {
      dns_name   = "${local.spoke1_us_psc_https_ctrl_run_dns}."
      local_data = "name=${local.spoke1_us_psc_https_ctrl_run_dns}.,type=A,ttl=300,rrdatas=${local.spoke1_us_ilb7_addr}"
    }
    ("${local.spoke1_prefix}dns-rp-rule-runapp") = {
      dns_name   = "*.run.app."
      local_data = "name=*.run.app.,type=A,ttl=300,rrdatas=${local.spoke1_psc_api_fr_addr}"
    }
    ("${local.spoke1_prefix}dns-rp-rule-gcr") = {
      dns_name   = "*.gcr.io."
      local_data = "name=*.gcr.io.,type=A,ttl=300,rrdatas=${local.spoke1_psc_api_fr_addr}"
    }
    ("${local.spoke1_prefix}dns-rp-rule-apis") = {
      dns_name   = "*.googleapis.com."
      local_data = "name=*.googleapis.com.,type=A,ttl=300,rrdatas=${local.spoke1_psc_api_fr_addr}"
    }
  }
  spoke1_dns_rp_rules_local_create = templatefile("../scripts/dns/rule-create.sh", {
    PROJECT = var.project_id_spoke1
    RP_NAME = "${local.spoke1_prefix}dns-rp"
    RULES   = local.spoke1_dns_rp_rules_local
  })
  spoke1_dns_rp_rules_local_delete = templatefile("../scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_spoke1
    RP_NAME = "${local.spoke1_prefix}dns-rp"
    RULES   = local.spoke1_dns_rp_rules_local
  })
}

resource "null_resource" "spoke1_dns_rp_rules_local" {
  depends_on = [null_resource.spoke1_dns_rp]
  triggers = {
    create = local.spoke1_dns_rp_rules_local_create
    delete = local.spoke1_dns_rp_rules_local_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# rules bypass

locals {
  spoke1_dns_rp_rules_bypass = {
    ("${local.spoke1_prefix}dns-rp-rule-bypass-www")    = { dns_name = "www.googleapis.com." }
    ("${local.spoke1_prefix}dns-rp-rule-bypass-ouath2") = { dns_name = "oauth2.googleapis.com." }
    ("${local.spoke1_prefix}dns-rp-rule-bypass-psc")    = { dns_name = "*.p.googleapis.com." }
  }
  spoke1_dns_rp_rules_bypass_create = templatefile("../scripts/dns/rule-bypass-create.sh", {
    PROJECT = var.project_id_spoke1
    RP_NAME = "${local.spoke1_prefix}dns-rp"
    RULES   = local.spoke1_dns_rp_rules_bypass
  })
  spoke1_dns_rp_rules_bypass_delete = templatefile("../scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_spoke1
    RP_NAME = "${local.spoke1_prefix}dns-rp"
    RULES   = local.spoke1_dns_rp_rules_bypass
  })
}

resource "null_resource" "spoke1_dns_rp_rules_bypass" {
  depends_on = [null_resource.spoke1_dns_rp]
  triggers = {
    create = local.spoke1_dns_rp_rules_bypass_create
    delete = local.spoke1_dns_rp_rules_bypass_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# cloud dns
#---------------------------------

# psc zone

module "spoke1_dns_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_spoke1
  type        = "private"
  name        = "${local.spoke1_prefix}psc"
  domain      = "${local.spoke1_psc_api_fr_name}.p.googleapis.com."
  description = "psc"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link,
  ]
  recordsets = {
    "A " = { type = "A", ttl = 300, records = [local.spoke1_psc_api_fr_addr] }
  }
}

# local zone

module "spoke1_dns_private_zone" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_spoke1
  type        = "private"
  name        = "${local.spoke1_prefix}private"
  domain      = "${local.spoke1_domain}.${local.cloud_domain}."
  description = "spoke1 network attached"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link,
  ]
  recordsets = {
    "A ${local.spoke1_eu_ilb4_dns}" = { type = "A", ttl = 300, records = [local.spoke1_eu_ilb4_addr] },
    "A ${local.spoke1_us_ilb4_dns}" = { type = "A", ttl = 300, records = [local.spoke1_us_ilb4_addr] },
    "A ${local.spoke1_eu_ilb7_dns}" = { type = "A", ttl = 300, records = [local.spoke1_eu_ilb7_addr] },
    "A ${local.spoke1_us_ilb7_dns}" = { type = "A", ttl = 300, records = [local.spoke1_us_ilb7_addr] },
  }
}

# onprem zone

module "spoke1_dns_peering_to_hub_to_onprem" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id      = var.project_id_spoke1
  type            = "peering"
  name            = "${local.spoke1_prefix}to-hub-to-onprem"
  domain          = "${local.onprem_domain}."
  description     = "peering to hub for onprem"
  client_networks = [google_compute_network.spoke1_vpc.self_link]
  peer_network    = google_compute_network.hub_vpc.self_link
}

# sd zone

module "spoke1_sd_td" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_spoke1
  type        = "service-directory"
  name        = "${local.spoke1_prefix}sd-td"
  domain      = "${local.spoke1_td_domain}."
  description = google_service_directory_namespace.spoke1_td.id
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link,
  ]
  service_directory_namespace = google_service_directory_namespace.spoke1_td.id
}

module "spoke1_sd_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_spoke1
  type        = "service-directory"
  name        = "${local.spoke1_prefix}sd-psc"
  domain      = "${local.spoke1_psc_domain}."
  description = google_service_directory_namespace.spoke1_psc.id
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link,
  ]
  service_directory_namespace = google_service_directory_namespace.spoke1_psc.id
}

# reverse zone

locals {
  _spoke1_eu_subnet1_reverse_custom         = split("/", local.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"].ip_cidr_range).0
  _spoke1_us_subnet1_reverse_custom         = split("/", local.spoke1_subnets["${local.spoke1_prefix}us-subnet1"].ip_cidr_range).0
  _spoke1_eu_random_google_reverse_internal = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"].ip_cidr_range, 254)
  spoke1_eu_subnet1_reverse_custom = (format("%s.%s.%s.in-addr.arpa.",
    element(split(".", local._spoke1_eu_subnet1_reverse_custom), 2),
    element(split(".", local._spoke1_eu_subnet1_reverse_custom), 1),
    element(split(".", local._spoke1_eu_subnet1_reverse_custom), 0),
  ))
  spoke1_us_subnet1_reverse_custom = (format("%s.%s.%s.in-addr.arpa.",
    element(split(".", local._spoke1_us_subnet1_reverse_custom), 2),
    element(split(".", local._spoke1_us_subnet1_reverse_custom), 1),
    element(split(".", local._spoke1_us_subnet1_reverse_custom), 0),
  ))
  spoke1_eu_random_google_reverse_internal = (format("%s.%s.%s.%s.in-addr.arpa.",
    element(split(".", local._spoke1_eu_random_google_reverse_internal), 3),
    element(split(".", local._spoke1_eu_random_google_reverse_internal), 2),
    element(split(".", local._spoke1_eu_random_google_reverse_internal), 1),
    element(split(".", local._spoke1_eu_random_google_reverse_internal), 0),
  ))
}

# reverse lookup zone (self-managed reverse lookup zones)

module "spoke1_eu_subnet1_reverse_custom" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_spoke1
  type        = "private"
  name        = "${local.spoke1_prefix}eu-subnet1-reverse-custom"
  domain      = local.spoke1_eu_subnet1_reverse_custom
  description = "eu-subnet1 reverse custom zone"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link,
  ]
  recordsets = {
    "PTR 30" = { type = "PTR", ttl = 300, records = ["${local.spoke1_eu_ilb4_dns}.${local.spoke1_domain}.${local.cloud_domain}."] },
    "PTR 40" = { type = "PTR", ttl = 300, records = ["${local.spoke1_eu_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}."] },
  }
}

module "spoke1_us_subnet1_reverse_custom" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns?ref=v15.0.0"
  project_id  = var.project_id_spoke1
  type        = "private"
  name        = "${local.spoke1_prefix}us-subnet1-reverse-custom"
  domain      = local.spoke1_us_subnet1_reverse_custom
  description = "us-subnet1 reverse custom zone"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link,
  ]
  recordsets = {
    "PTR 30" = { type = "PTR", ttl = 300, records = ["${local.spoke1_us_ilb4_dns}.${local.spoke1_domain}.${local.cloud_domain}."] },
    "PTR 40" = { type = "PTR", ttl = 300, records = ["${local.spoke1_us_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}."] },
  }
}

# reverse zone (google-managed reverse lookup for everything else)

resource "google_dns_managed_zone" "spoke1_eu_random_google_reverse_internal" {
  provider       = google-beta
  project        = var.project_id_spoke1
  name           = "${local.spoke1_prefix}eu-random-google-reverse-internal"
  dns_name       = local.spoke1_eu_random_google_reverse_internal
  description    = "random reverse internal zone"
  visibility     = "private"
  reverse_lookup = true
  private_visibility_config {
    networks { network_url = google_compute_network.hub_vpc.self_link }
    networks { network_url = google_compute_network.spoke1_vpc.self_link }
    networks { network_url = google_compute_network.spoke2_vpc.self_link }
  }
}

# ilb4: eu
#---------------------------------

# instance

resource "google_compute_instance" "spoke1_eu_ilb4_vm" {
  project      = var.project_id_spoke1
  name         = "${local.spoke1_prefix}eu-ilb4-vm"
  zone         = "${local.spoke1_eu_region}-b"
  machine_type = var.machine_type
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
  service_account {
    email  = module.spoke1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# instance group

resource "google_compute_instance_group" "spoke1_eu_ilb4_ig" {
  project   = var.project_id_spoke1
  zone      = "${local.spoke1_eu_region}-b"
  name      = "${local.spoke1_prefix}eu-ilb4-ig"
  instances = [google_compute_instance.spoke1_eu_ilb4_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# ilb4

module "spoke1_eu_ilb4" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb?ref=v15.0.0"
  project_id    = var.project_id_spoke1
  region        = local.spoke1_eu_region
  name          = "${local.spoke1_prefix}eu-ilb4"
  service_label = "${local.spoke1_prefix}eu-ilb4"
  network       = google_compute_network.spoke1_vpc.self_link
  subnetwork    = local.spoke1_eu_subnet1.self_link
  address       = local.spoke1_eu_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.spoke1_eu_ilb4_ig.self_link
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

# ilb7: eu
#---------------------------------

# domains

locals {
  spoke1_eu_ilb7_domains = [
    "${local.spoke1_eu_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}",
    local.spoke1_eu_psc_https_ctrl_run_dns
  ]
}

# instance

resource "google_compute_instance" "spoke1_eu_ilb7_vm" {
  project      = var.project_id_spoke1
  name         = "${local.spoke1_prefix}eu-ilb7-vm"
  zone         = "${local.spoke1_eu_region}-b"
  machine_type = var.machine_type
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
  service_account {
    email  = module.spoke1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# instance group

resource "google_compute_instance_group" "spoke1_eu_ilb7_ig" {
  project   = var.project_id_spoke1
  zone      = "${local.spoke1_eu_region}-b"
  name      = "${local.spoke1_prefix}eu-ilb7-ig"
  instances = [google_compute_instance.spoke1_eu_ilb7_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# psc api neg

locals {
  spoke1_eu_ilb7_psc_api_neg_name      = "${local.spoke1_prefix}eu-ilb7-psc-api-neg"
  spoke1_eu_ilb7_psc_api_neg_self_link = "projects/${var.project_id_spoke1}/regions/${local.spoke1_eu_region}/networkEndpointGroups/${local.spoke1_eu_ilb7_psc_api_neg_name}"
  spoke1_eu_ilb7_psc_api_neg_create = templatefile("../scripts/neg/psc/create.sh", {
    PROJECT_ID     = var.project_id_spoke1
    NETWORK        = google_compute_network.spoke1_vpc.self_link
    REGION         = local.spoke1_eu_region
    NEG_NAME       = local.spoke1_eu_ilb7_psc_api_neg_name
    TARGET_SERVICE = local.spoke1_eu_psc_https_ctrl_run_dns
  })
  spoke1_eu_ilb7_psc_api_neg_delete = templatefile("../scripts/neg/psc/delete.sh", {
    PROJECT_ID = var.project_id_spoke1
    REGION     = local.spoke1_eu_region
    NEG_NAME   = local.spoke1_eu_ilb7_psc_api_neg_name
  })
}

resource "null_resource" "spoke1_eu_ilb7_psc_api_neg" {
  triggers = {
    create = local.spoke1_eu_ilb7_psc_api_neg_create
    delete = local.spoke1_eu_ilb7_psc_api_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# psc vpc neg
/*
locals {
  spoke1_us_ilb7_psc_vpc_neg_name      = "${local.spoke1_prefix}us-ilb7-psc-vpc-neg"
  spoke1_us_ilb7_psc_vpc_neg_self_link = "projects/${var.project_id_spoke1}/regions/${local.spoke1_us_region}/networkEndpointGroups/${local.spoke1_us_ilb7_psc_vpc_neg_name}"
  spoke1_us_ilb7_psc_vpc_neg_create = templatefile("../scripts/neg/psc/create.sh", {
    PROJECT_ID     = var.project_id_spoke1
    NETWORK        = google_compute_network.spoke1_vpc.self_link
    REGION         = local.spoke1_us_region
    NEG_NAME       = local.spoke1_us_ilb7_psc_vpc_neg_name
    TARGET_SERVICE = local.spoke1_us_psc_https_ctrl_run_dns
    #TARGET_SERVICE = google_compute_service_attachment.spoke2_us_producer_svc_attach.self_link
  })
  spoke1_us_ilb7_psc_vpc_neg_delete = templatefile("../scripts/neg/psc/delete.sh", {
    PROJECT_ID = var.project_id_spoke1
    REGION     = local.spoke1_us_region
    NEG_NAME   = local.spoke1_us_ilb7_psc_vpc_neg_name
  })
}

resource "null_resource" "spoke1_us_ilb7_psc_vpc_neg" {
  triggers = {
    create = local.spoke1_us_ilb7_psc_vpc_neg_create
    delete = local.spoke1_us_ilb7_psc_vpc_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}*/

# backend

locals {
  spoke1_eu_ilb7_backend_services_mig = {
    ("main") = {
      port_name = local.svc_web.name
      backends = [
        {
          group                 = google_compute_instance_group.spoke1_eu_ilb7_ig.self_link
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
  spoke1_eu_ilb7_backend_services_psc_neg = {
    ("api") = {
      port = local.svc_web.port
      backends = [
        {
          group           = local.spoke1_eu_ilb7_psc_api_neg_self_link
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
  spoke1_eu_ilb7_backend_services_neg = {}
}

# backend services

module "spoke1_eu_ilb7_bes" {
  depends_on               = [null_resource.spoke1_eu_ilb7_psc_api_neg]
  source                   = "../modules/backend-region"
  project_id               = var.project_id_spoke1
  prefix                   = "${local.spoke1_prefix}eu-ilb7"
  network                  = google_compute_network.spoke1_vpc.self_link
  region                   = local.spoke1_eu_region
  backend_services_mig     = local.spoke1_eu_ilb7_backend_services_mig
  backend_services_neg     = local.spoke1_eu_ilb7_backend_services_neg
  backend_services_psc_neg = local.spoke1_eu_ilb7_backend_services_psc_neg
}

# url map

resource "google_compute_region_url_map" "spoke1_eu_ilb7_url_map" {
  provider        = google-beta
  project         = var.project_id_spoke1
  name            = "${local.spoke1_prefix}eu-ilb7-url-map"
  region          = local.spoke1_eu_region
  default_service = module.spoke1_eu_ilb7_bes.backend_service_mig["main"].id
  host_rule {
    path_matcher = "main"
    hosts        = ["${local.spoke1_eu_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}"]
  }
  host_rule {
    path_matcher = "api"
    hosts        = [local.spoke1_eu_psc_https_ctrl_run_dns]
  }
  path_matcher {
    name            = "main"
    default_service = module.spoke1_eu_ilb7_bes.backend_service_mig["main"].self_link
  }
  path_matcher {
    name            = "api"
    default_service = module.spoke1_eu_ilb7_bes.backend_service_psc_neg["api"].self_link
  }
}

# frontend

module "spoke1_eu_ilb7_frontend" {
  source           = "../modules/int-lb-app-frontend"
  project_id       = var.project_id_spoke1
  prefix           = "${local.spoke1_prefix}eu-ilb7"
  network          = google_compute_network.spoke1_vpc.self_link
  subnetwork       = local.spoke1_eu_subnet1.self_link
  proxy_subnetwork = [local.spoke1_eu_subnet3]
  region           = local.spoke1_eu_region
  url_map          = google_compute_region_url_map.spoke1_eu_ilb7_url_map.id
  frontend = {
    address = local.spoke1_eu_ilb7_addr
    ssl     = { self_cert = true, domains = local.spoke1_eu_ilb7_domains }
  }
}
