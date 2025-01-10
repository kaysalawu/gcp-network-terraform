# !!!!!!!!!!!!!! WIP not working yet
#######################################################
# uncomment this section after manually deploying the
# gke cluster app which creates the negs referenced
# in the resources below
#######################################################

# td
#---------------------------------

data "google_compute_network_endpoint_group" "spoke2_us_gke_neg_b" {
  project = var.project_id_spoke2
  name    = "${local.spoke2_prefix}us-gke-neg"
  zone    = "${local.spoke2_us_region}-b"
}

data "google_compute_network_endpoint_group" "spoke2_us_gke_neg_c" {
  project = var.project_id_spoke2
  name    = "${local.spoke2_prefix}us-gke-neg"
  zone    = "${local.spoke2_us_region}-c"
}

# td
#---------------------------------

# health check

resource "google_compute_health_check" "spoke2_gke_hc" {
  project = var.project_id_spoke2
  name    = "${local.spoke2_prefix}gke-hc"
  http_health_check {
    port = local.svc_web.port
  }
}

# backend service

resource "google_compute_backend_service" "spoke2_gke_be_svc" {
  provider = google-beta
  project  = var.project_id_spoke2
  name     = "${local.spoke2_prefix}gke-be-svc"
  protocol = "HTTP"
  backend {
    group                 = data.google_compute_network_endpoint_group.spoke2_us_gke_neg_b.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 5
  }
  backend {
    group                 = data.google_compute_network_endpoint_group.spoke2_us_gke_neg_c.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 5
  }
  health_checks         = [google_compute_health_check.spoke2_gke_hc.self_link]
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
}

# url map

resource "google_compute_url_map" "spoke2_gke_url_map" {
  provider = google-beta
  project  = var.project_id_spoke2
  name     = "${local.spoke2_prefix}gke-url-map"
  host_rule {
    path_matcher = "gke"
    hosts        = ["${local.spoke2_prefix}us-gke-svc"]
  }
  path_matcher {
    name            = "gke"
    default_service = google_compute_backend_service.spoke2_gke_be_svc.self_link
  }
  default_service = google_compute_backend_service.spoke2_gke_be_svc.self_link
}

# gke proxy

resource "google_compute_target_http_proxy" "spoke2_gke_http_proxy" {
  project = var.project_id_spoke2
  name    = "${local.spoke2_prefix}gke-http-proxy"
  url_map = google_compute_url_map.spoke2_gke_url_map.self_link
}

# forwarding rule

resource "google_compute_global_forwarding_rule" "spoke2_td_gke_fr" {
  provider   = google-beta
  project    = var.project_id_spoke2
  name       = "${local.spoke2_prefix}spoke2-td-gke-fr"
  target     = google_compute_target_http_proxy.spoke2_gke_http_proxy.self_link
  network    = module.spoke2_vpc.self_link
  ip_address = local.spoke2_td_global_gke_svc_addr
  port_range = local.svc_web.port

  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
}

output "busy_box_test" {
  value = "wget -q --header 'Host: ${local.spoke2_prefix}us-gke-svc' -O - ${local.spoke2_td_global_gke_svc_addr}; echo"
}
