
locals {
  prefix = var.prefix == "" ? "" : join("-", [var.prefix, ""])
}

# self-signed certificate
#---------------------------------

# root ca

resource "tls_private_key" "root_ca" {
  count     = var.frontend.ssl.self_cert ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "root_ca" {
  count           = var.frontend.ssl.self_cert ? 1 : 0
  private_key_pem = tls_private_key.root_ca.0.private_key_pem
  subject {
    common_name         = "cloudtuple ca"
    organization        = "cloudtuple"
    organizational_unit = "cloudtuple ca team"
    street_address      = ["mpls chicken road"]
    locality            = "London"
    province            = "England"
    country             = "UK"
  }
  is_ca_certificate     = true
  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]
}

# client

resource "tls_private_key" "client" {
  count     = var.frontend.ssl.self_cert ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client" {
  count           = var.frontend.ssl.self_cert ? 1 : 0
  private_key_pem = tls_private_key.client.0.private_key_pem
  subject {
    common_name         = "cloudtuple gcp"
    organization        = "cloudtuple"
    organizational_unit = "cloudtuple gcp team"
    street_address      = ["mpls chicken road"]
    locality            = "London"
    province            = "England"
    country             = "UK"
  }
  dns_names = var.frontend.ssl.domains
}

resource "tls_locally_signed_cert" "client" {
  count                 = var.frontend.ssl.self_cert ? 1 : 0
  cert_request_pem      = tls_cert_request.client.0.cert_request_pem
  ca_private_key_pem    = tls_private_key.root_ca.0.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.root_ca.0.cert_pem
  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "google_compute_region_ssl_certificate" "this" {
  count       = var.frontend.ssl.self_cert ? 1 : 0
  project     = var.project_id
  region      = var.region
  name_prefix = "${local.prefix}ssl-cert"
  private_key = tls_private_key.client.0.private_key_pem
  certificate = tls_locally_signed_cert.client.0.cert_pem
  lifecycle {
    create_before_destroy = true
  }
}

# address
#---------------------------------

resource "google_compute_address" "this" {
  provider     = google-beta
  project      = var.project_id
  subnetwork   = var.subnetwork
  region       = var.region
  address      = var.frontend.address
  name         = "${local.prefix}address-${var.region}"
  address_type = "INTERNAL"
  purpose      = "SHARED_LOADBALANCER_VIP"
}

# url map (redirect)
#---------------------------------

resource "google_compute_region_url_map" "redirect" {
  provider = google-beta
  project  = var.project_id
  name     = "${local.prefix}url-map-redirect"
  region   = var.region
  default_url_redirect {
    https_redirect         = true
    strip_query            = false
    redirect_response_code = "PERMANENT_REDIRECT"
  }
}

# target proxy
#---------------------------------

# https

resource "google_compute_region_target_https_proxy" "this" {
  provider         = google-beta
  project          = var.project_id
  name             = "${local.prefix}https-proxy"
  region           = var.region
  url_map          = var.url_map
  ssl_certificates = [google_compute_region_ssl_certificate.this[0].self_link]
}

# redirect

resource "google_compute_region_target_http_proxy" "redirect" {
  provider = google-beta
  project  = var.project_id
  name     = "${local.prefix}http-proxy-redirect"
  region   = var.region
  url_map  = google_compute_region_url_map.redirect.self_link
}

# forwarding rule
#---------------------------------

# redirect

resource "google_compute_forwarding_rule" "redirect" {
  depends_on            = [var.proxy_subnetwork]
  provider              = google-beta
  project               = var.project_id
  name                  = "${local.prefix}http-fr"
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  network               = var.network
  subnetwork            = var.subnetwork
  ip_address            = var.frontend.address == null ? google_compute_address.this.address : var.frontend.address
  network_tier          = "PREMIUM"
  port_range            = 80
  target                = google_compute_region_target_http_proxy.redirect.self_link
}

# https

resource "google_compute_forwarding_rule" "https" {
  depends_on            = [var.proxy_subnetwork]
  provider              = google-beta
  project               = var.project_id
  name                  = "${local.prefix}https-fr"
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  network               = var.network
  subnetwork            = var.subnetwork
  ip_address            = var.frontend.address == null ? google_compute_address.this.address : var.frontend.address
  network_tier          = "PREMIUM"
  port_range            = 443
  target                = google_compute_region_target_https_proxy.this.self_link
}
