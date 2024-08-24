
# instance
#----------------------------------------------------

# eu

resource "google_compute_instance" "spoke2_eu_xlb7" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}eu-xlb7"
  zone         = "${local.spoke2_eu_region}-b"
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
    network    = google_compute_network.spoke2_vpc.self_link
    subnetwork = local.spoke2_eu_subnet1.self_link
  }
  service_account {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.vm_lite_startup
}

resource "google_compute_instance" "spoke2_eu_xlb7_hc_proxy" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}eu-xlb7-hc-proxy"
  zone         = "${local.spoke2_eu_region}-b"
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
    network    = google_compute_network.spoke2_vpc.self_link
    subnetwork = local.spoke2_eu_subnet1.self_link
    network_ip = local.spoke2_eu_hybrid_hc_proxy_addr
  }
  service_account {
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = templatefile("../scripts/startup/proxy_hc.sh", {
    GFE_RANGES = local.netblocks.gfe
    DNAT_IP    = local.site1_app1_addr
  })
}

# us

resource "google_compute_instance" "spoke2_us_xlb7" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}us-xlb7"
  zone         = "${local.spoke2_us_region}-b"
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
    network    = google_compute_network.spoke2_vpc.self_link
    subnetwork = local.spoke2_us_subnet1.self_link
  }
  service_account {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.vm_lite_startup
}

# instance group
#----------------------------------------------------

# eu

resource "google_compute_instance_group" "spoke2_eu_xlb7_ig" {
  project   = var.project_id_spoke2
  zone      = "${local.spoke2_eu_region}-b"
  name      = "${local.spoke2_prefix}eu-xlb7-ig"
  instances = [google_compute_instance.spoke2_eu_xlb7.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# us

resource "google_compute_instance_group" "spoke2_us_xlb7_ig" {
  project   = var.project_id_spoke2
  zone      = "${local.spoke2_us_region}-b"
  name      = "${local.spoke2_prefix}us-xlb7-ig"
  instances = [google_compute_instance.spoke2_us_xlb7.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# neg
#----------------------------------------------------

# eu

locals {
  spoke2_eu_xlb7_hybrid_neg_create = templatefile("../scripts/neg/hybrid/create.sh", {
    PROJECT_ID  = var.project_id_spoke2
    NETWORK     = google_compute_network.spoke2_vpc.name
    SUBNET      = local.spoke2_eu_subnet1.name
    NEG_NAME    = "${local.spoke2_prefix}eu-xlb7-hybrid-neg"
    ZONE        = "${local.spoke2_eu_region}-c"
    NE_TYPE     = "non-gcp-private-ip-port"
    REMOTE_IP   = local.spoke2_eu_hybrid_hc_proxy_addr
    REMOTE_PORT = local.svc_web.port
  })
  spoke2_eu_xlb7_hybrid_neg_delete = templatefile("../scripts/neg/hybrid/delete.sh", {
    PROJECT_ID = var.project_id_spoke2
    NEG_NAME   = "${local.spoke2_prefix}eu-xlb7-hybrid-neg"
    ZONE       = "${local.spoke2_eu_region}-c"
  })
}

resource "null_resource" "spoke2_eu_xlb7_hybrid_neg" {
  triggers = {
    create = local.spoke2_eu_xlb7_hybrid_neg_create
    delete = local.spoke2_eu_xlb7_hybrid_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

data "google_compute_network_endpoint_group" "spoke2_eu_xlb7_hybrid_neg" {
  depends_on = [null_resource.spoke2_eu_xlb7_hybrid_neg]
  project    = var.project_id_spoke2
  name       = "${local.spoke2_prefix}eu-xlb7-hybrid-neg"
  zone       = "${local.spoke2_eu_region}-c"
}

locals {
  ssl_cert_domains = ["sample.${data.google_dns_managed_zone.public_zone.dns_name}", ]
  url_map_hosts    = [for host in local.ssl_cert_domains : trimsuffix(host, ".")]
}

# xlb7
#----------------------------------------------------

module "spoke2_xlb7" {
  source     = "../modules/xlb7"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}xlb7"
  network    = google_compute_network.spoke2_vpc.self_link
  frontend = {
    port          = 80
    ssl           = { self_cert = false, domains = local.ssl_cert_domains }
    standard_tier = { enable = false, region = local.spoke2_eu_region }
  }
  mig_config = {
    port_name = local.svc_web.name
    backends = [
      {
        group          = google_compute_instance_group.spoke2_eu_xlb7_ig.self_link
        balancing_mode = "UTILIZATION", capacity_scaler = 1.0
      },
      {
        group          = google_compute_instance_group.spoke2_us_xlb7_ig.self_link
        balancing_mode = "UTILIZATION", capacity_scaler = 1.0
      }
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
  neg_config = {
    port = local.svc_web.port
    backends = [
      {
        group                 = data.google_compute_network_endpoint_group.spoke2_eu_xlb7_hybrid_neg.id
        balancing_mode        = "RATE"
        max_rate_per_endpoint = 5
      }
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
  url_map = google_compute_url_map.spoke2_xlb7_url_map.id
}

# dns
#----------------------------------------------------

resource "google_dns_record_set" "spoke2_xlb7_dns" {
  for_each     = toset(local.ssl_cert_domains)
  project      = var.project_id_hub
  managed_zone = data.google_dns_managed_zone.public_zone.name
  name         = "sample.${data.google_dns_managed_zone.public_zone.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [module.spoke2_xlb7.forwarding_rule.ip_address]
}

# url map
#----------------------------------------------------

resource "google_compute_url_map" "spoke2_xlb7_url_map" {
  provider        = google-beta
  project         = var.project_id_spoke2
  name            = "${local.spoke2_prefix}xlb7-url-map"
  default_service = module.spoke2_xlb7.backend_service_mig.self_link
  host_rule {
    path_matcher = "host"
    hosts        = local.url_map_hosts
  }
  path_matcher {
    name = "host"
    route_rules {
      priority = 1
      match_rules {
        prefix_match = "/mig"
      }
      route_action {
        url_rewrite {
          path_prefix_rewrite = "/"
        }
      }
      service = module.spoke2_xlb7.backend_service_mig.self_link
    }
    route_rules {
      priority = 2
      match_rules {
        prefix_match = "/neg"
      }
      route_action {
        url_rewrite {
          path_prefix_rewrite = "/"
        }
      }
      service = module.spoke2_xlb7.backend_service_neg.self_link
    }
    default_service = module.spoke2_xlb7.backend_service_mig.self_link
  }
}

resource "google_compute_url_map" "spoke2_xlb7_url_map_redirect" {
  provider = google-beta
  project  = var.project_id_spoke2
  name     = "${local.spoke2_prefix}xlb-url-map-redirect"
  default_url_redirect {
    https_redirect         = true
    strip_query            = false
    redirect_response_code = "PERMANENT_REDIRECT"
  }
}
