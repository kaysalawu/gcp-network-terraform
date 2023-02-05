
locals {
  prefix = var.prefix == "" ? "" : join("-", [var.prefix, ""])
  compute_address_resource = try(
    google_compute_global_address.global.0,
    google_compute_address.regional.0,
    {}
  )
  target_proxy_resource = try(
    google_compute_target_https_proxy.https,
    google_compute_target_http_proxy.http,
    {}
  )
  forwarding_rule_resource = try(
    google_compute_global_forwarding_rule.global.0,
    google_compute_forwarding_rule.regional.0,
    {}
  )
  certificate_resource = try(
    google_compute_ssl_certificate.this.0,
    google_compute_managed_ssl_certificate.this.0,
    {}
  )
}

# managed certificate
#---------------------------------

resource "google_compute_managed_ssl_certificate" "this" {
  count    = var.frontend.ssl.self_cert ? 0 : 1
  provider = google-beta
  project  = var.project_id
  name     = "${local.prefix}google-cert"
  managed {
    domains = var.frontend.ssl.domains
  }
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
  key_algorithm   = tls_private_key.root_ca.0.algorithm
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
  key_algorithm   = tls_private_key.client.0.algorithm
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
  ca_key_algorithm      = tls_self_signed_cert.root_ca.0.key_algorithm
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

resource "google_compute_ssl_certificate" "this" {
  count       = var.frontend.ssl.self_cert ? 1 : 0
  project     = var.project_id
  name_prefix = "${local.prefix}ssl-cert"
  private_key = tls_private_key.client.0.private_key_pem
  certificate = tls_locally_signed_cert.client.0.cert_pem
  lifecycle {
    create_before_destroy = true
  }
}

# ssl policy
#---------------------------------

resource "google_compute_ssl_policy" "this" {
  provider        = google-beta
  project         = var.project_id
  name            = "${local.prefix}ssl-policy-modern"
  profile         = "COMPATIBLE"
  min_tls_version = "TLS_1_0"
}

# address
#---------------------------------

resource "google_compute_global_address" "global" {
  count    = !var.frontend.regional.enable ? 1 : 0
  provider = google-beta
  project  = var.project_id
  name     = "${local.prefix}global-addr"
}

resource "google_compute_address" "regional" {
  count        = var.frontend.regional.enable ? 1 : 0
  provider     = google-beta
  project      = var.project_id
  name         = "${local.prefix}regional-addr"
  network_tier = "STANDARD"
  region       = var.frontend.regional.region
}

# url map (redirect)
#---------------------------------

resource "google_compute_url_map" "redirect" {
  provider = google-beta
  project  = var.project_id
  name     = "${local.prefix}url-map-redirect"
  default_url_redirect {
    https_redirect         = true
    strip_query            = false
    redirect_response_code = "PERMANENT_REDIRECT"
  }
}

# target proxy
#---------------------------------

resource "google_compute_target_http_proxy" "http" {
  provider = google-beta
  project  = var.project_id
  name     = "${local.prefix}http-proxy"
  url_map  = var.url_map
}

resource "google_compute_target_https_proxy" "https" {
  provider         = google-beta
  project          = var.project_id
  name             = "${local.prefix}https-proxy"
  url_map          = var.url_map
  ssl_policy       = google_compute_ssl_policy.this.self_link
  ssl_certificates = [local.certificate_resource.self_link]
}

# redirect

resource "google_compute_target_http_proxy" "redirect" {
  provider = google-beta
  project  = var.project_id
  name     = "${local.prefix}http-proxy-redirect"
  url_map  = google_compute_url_map.redirect.self_link
}

# forwarding rule
#---------------------------------

# redirect

resource "google_compute_forwarding_rule" "regional_redirect" {
  count        = var.frontend.regional.enable ? 1 : 0
  provider     = google-beta
  project      = var.project_id
  name         = "${local.prefix}regional-fr-redirect"
  region       = var.frontend.regional.region
  network_tier = "STANDARD"
  ip_address   = var.address == null ? local.compute_address_resource.address : var.address
  port_range   = "80"
  target       = google_compute_target_http_proxy.redirect.self_link
}

resource "google_compute_global_forwarding_rule" "global_redirect" {
  count      = !var.frontend.regional.enable ? 1 : 0
  provider   = google-beta
  project    = var.project_id
  name       = "${local.prefix}global-fr-redirect"
  ip_address = var.address == null ? local.compute_address_resource.address : var.address
  port_range = "80"
  target     = google_compute_target_http_proxy.redirect.self_link
}

# main

resource "google_compute_forwarding_rule" "regional" {
  count        = var.frontend.regional.enable ? 1 : 0
  provider     = google-beta
  project      = var.project_id
  name         = "${local.prefix}regional-fr"
  region       = var.frontend.regional.region
  network_tier = "STANDARD"
  ip_address   = var.address == null ? local.compute_address_resource.address : var.address
  port_range   = 443
  target       = local.target_proxy_resource.self_link
}

resource "google_compute_global_forwarding_rule" "global" {
  count      = !var.frontend.regional.enable ? 1 : 0
  provider   = google-beta
  project    = var.project_id
  name       = "${local.prefix}global-fr"
  ip_address = var.address == null ? local.compute_address_resource.address : var.address
  port_range = 443
  target     = local.target_proxy_resource.self_link
}
