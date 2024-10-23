
module "spoke2_psc_api_ilb7_api" {
  source         = "../../modules/psc-api-ilb7"
  project_id     = var.project_id_spoke2
  name           = "${local.spoke2_prefix}us-psc-api-ilb7"
  network        = google_compute_network.spoke2_vpc.self_link
  subnetwork     = local.spoke2_us_subnet1.self_link
  region         = local.spoke2_us_region
  zone           = "${local.spoke2_us_region}-b"
  port_range     = 443
  target_service = local.spoke2_us_psc_api_ilb7_svc
  service_dns    = local.spoke2_eu_psc_api_ilb7_dns # for cert san and url-map

  service_directory_namespace    = google_service_directory_namespace.spoke2_psc.id
  service_directory_service_name = local.spoke2_psc_api_ilb7_host
}

# ilb7
#---------------------------------

locals {
  spoke2_us_ilb7_host             = "${local.spoke2_us_ilb7_dns}."
  spoke2_us_ilb7_domains          = [local.spoke2_us_ilb7_host]
  spoke2_us_ilb7_ssl_cert_domains = [for x in local.spoke2_us_ilb7_domains : trimsuffix(x, ".")]
}

# ig

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
  spoke2_us_ilb7_psc_neg_name      = "${local.spoke2_prefix}us-ilb7-psc-neg"
  spoke2_us_ilb7_psc_neg_self_link = "projects/${var.project_id_spoke2}/regions/${local.spoke2_us_region}/networkEndpointGroups/${local.spoke2_us_ilb7_psc_neg_name}"
  spoke2_us_ilb7_psc_neg_create = templatefile("../../scripts/neg/psc7/create.sh", {
    PROJECT_ID     = var.project_id_spoke2
    NETWORK        = google_compute_network.spoke2_vpc.self_link
    REGION         = local.spoke2_us_region
    NEG_NAME       = local.spoke2_us_ilb7_psc_neg_name
    TARGET_SERVICE = local.spoke2_us_psc_api_ilb7_svc
  })
  spoke2_us_ilb7_psc_neg_delete = templatefile("../../scripts/neg/psc7/delete.sh", {
    PROJECT_ID = var.project_id_spoke2
    REGION     = local.spoke2_us_region
    NEG_NAME   = local.spoke2_us_ilb7_psc_neg_name
  })
}

resource "null_resource" "spoke2_us_ilb7_psc_neg" {
  triggers = {
    create = local.spoke2_us_ilb7_psc_neg_create
    delete = local.spoke2_us_ilb7_psc_neg_delete
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
    ("x") = {
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
    ("psc") = {
      port = local.svc_web.port
      backends = [
        {
          group           = local.spoke2_us_ilb7_psc_neg_self_link
          balancing_mode  = "UTILIZATION"
          capacity_scaler = 1.0
        },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check = {
          port         = local.svc_web.port
          host         = local.uhc_config.host
          request_path = "/${local.uhc_config.request_path}"
          response     = local.uhc_config.response
        }
      }
    }
  }
  spoke2_us_ilb7_backend_services_neg = {}
}

module "spoke2_us_ilb7_bes" {
  source                   = "../../modules/backend-region"
  project_id               = var.project_id_spoke2
  prefix                   = "${local.spoke2_prefix}us-ilb7"
  network                  = google_compute_network.spoke2_vpc.self_link
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
  default_service = module.spoke2_us_ilb7_bes.backend_service_mig["x"].id
}

# frontend

module "spoke2_us_ilb7_frontend" {
  source           = "../../modules/int-lb-app-frontend"
  project_id       = var.project_id_spoke2
  prefix           = "${local.spoke2_prefix}us-ilb7"
  network          = google_compute_network.spoke2_vpc.self_link
  subnetwork       = local.spoke2_us_subnet1.self_link
  proxy_subnetwork = [local.spoke2_us_subnet3]
  region           = local.spoke2_us_region
  url_map          = google_compute_region_url_map.spoke2_us_ilb7_url_map.id
  frontend = {
    http = {
      enable  = true
      address = local.spoke2_us_ilb7_addr
      port    = local.svc_web.port
    }
    https = {
      enable   = true
      address  = null
      port     = 443
      ssl      = { self_cert = true, domains = local.spoke2_us_ilb7_ssl_cert_domains }
      redirect = { enable = false, redirected_port = local.svc_web.port }
    }
  }
}
