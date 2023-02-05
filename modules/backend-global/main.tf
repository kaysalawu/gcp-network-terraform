
locals {
  prefix = var.prefix == "" ? "" : join("-", [var.prefix, ""])
}

# health check
#---------------------------------

# mig

resource "google_compute_health_check" "http_mig" {
  for_each            = var.backend_services_mig
  provider            = google-beta
  project             = var.project_id
  name                = "${local.prefix}http-mig-${each.key}"
  check_interval_sec  = try(each.value.health_check_config.config.check_interval_sec, null)
  healthy_threshold   = try(each.value.health_check_config.config.healthy_threshold, null)
  timeout_sec         = try(each.value.health_check_config.config.timeout_sec, null)
  unhealthy_threshold = try(each.value.health_check_config.config.unhealthy_threshold, null)
  http_health_check {
    host               = try(each.value.health_check_config.check.host, null)
    port               = try(each.value.health_check_config.check.port, null)
    port_name          = try(each.value.health_check_config.check.port_name, null)
    port_specification = try(each.value.health_check_config.check.port_specification, null)
    proxy_header       = try(each.value.health_check_config.check.proxy_header, null)
    request_path       = try(each.value.health_check_config.check.request_path, null)
    response           = try(each.value.health_check_config.check.response, null)
  }
  dynamic "log_config" {
    for_each = try(each.value.health_check_config.logging, false) ? [""] : []
    content {
      enable = true
    }
  }
}

# neg

resource "google_compute_health_check" "http_neg" {
  for_each            = var.backend_services_neg
  provider            = google-beta
  project             = var.project_id
  name                = "${local.prefix}http-neg-${each.key}"
  check_interval_sec  = try(each.value.health_check_config.config.check_interval_sec, null)
  healthy_threshold   = try(each.value.health_check_config.config.healthy_threshold, null)
  timeout_sec         = try(each.value.health_check_config.config.timeout_sec, null)
  unhealthy_threshold = try(each.value.health_check_config.config.unhealthy_threshold, null)
  http_health_check {
    host               = try(each.value.health_check_config.check.host, null)
    port               = try(each.value.health_check_config.check.port, null)
    port_name          = try(each.value.health_check_config.check.port_name, null)
    port_specification = try(each.value.health_check_config.check.port_specification, null)
    proxy_header       = try(each.value.health_check_config.check.proxy_header, null)
    request_path       = try(each.value.health_check_config.check.request_path, null)
    response           = try(each.value.health_check_config.check.response, null)
  }
  dynamic "log_config" {
    for_each = try(each.value.health_check_config.logging, false) ? [""] : []
    content {
      enable = true
    }
  }
}

# backend service
#---------------------------------

# mig

resource "google_compute_backend_service" "mig" {
  for_each        = var.backend_services_mig
  provider        = google-beta
  project         = var.project_id
  name            = "${local.prefix}bes-mig-${each.key}"
  port_name       = each.value.port_name
  protocol        = "HTTP"
  timeout_sec     = "30"
  security_policy = each.value.security_policy
  enable_cdn      = each.value.enable_cdn
  dynamic "backend" {
    for_each = { for b in each.value.backends : b.group => b }
    iterator = backend
    content {
      group                 = backend.key
      balancing_mode        = try(backend.value.balancing_mode, "RATE")
      max_rate_per_instance = try(backend.value.max_rate_per_endpoint, 900)
    }
  }
  custom_request_headers = [
    "X-CDN-Cache-ID:{cdn_cache_id}",
    "X-CDN-Cache-Status:{cdn_cache_status}",
    "X-Origin-Request-Header:{origin_request_header}",
    "X-Client-RTT-msec:{client_rtt_msec}",
    "X-Client-Region:{client_region}",
    "X-Client-Region-Subdivision:{client_region_subdivision}",
    "X-Client-City:{client_region},{client_city}",
    "X-Client-City-Lat-Long:{client_city_lat_long}",
    "X-TLS-SNI-Hostname:{tls_sni_hostname}",
    "X-TLS-Version:{tls_version}",
    "X-TLS-Cipher-Suite:{tls_cipher_suite}",
  ]
  health_checks = [google_compute_health_check.http_mig[each.key].self_link]
  log_config {
    enable      = true
    sample_rate = 1
  }
}

# neg

resource "google_compute_backend_service" "neg" {
  for_each        = var.backend_services_neg
  provider        = google-beta
  project         = var.project_id
  name            = "${local.prefix}bes-neg-${each.key}"
  protocol        = "HTTP"
  timeout_sec     = "30"
  security_policy = each.value.security_policy
  enable_cdn      = each.value.enable_cdn
  dynamic "backend" {
    for_each = { for b in each.value.backends : b.group => b }
    iterator = backend
    content {
      group                 = backend.key
      balancing_mode        = try(backend.value.balancing_mode, "RATE")
      max_rate_per_endpoint = try(backend.value.max_rate_per_endpoint, 5)
    }
  }
  custom_request_headers = [
    "X-CDN-Cache-ID:{cdn_cache_id}",
    "X-CDN-Cache-Status:{cdn_cache_status}",
    "X-Origin-Request-Header:{origin_request_header}",
    "X-Client-RTT-msec:{client_rtt_msec}",
    "X-Client-Region:{client_region}",
    "X-Client-Region-Subdivision:{client_region_subdivision}",
    "X-Client-City:{client_region},{client_city}",
    "X-Client-City-Lat-Long:{client_city_lat_long}",
    "X-TLS-SNI-Hostname:{tls_sni_hostname}",
    "X-TLS-Version:{tls_version}",
    "X-TLS-Cipher-Suite:{tls_cipher_suite}",
  ]
  health_checks = [google_compute_health_check.http_neg[each.key].self_link]
  log_config {
    enable      = true
    sample_rate = 1
  }
}

# psc neg

resource "google_compute_backend_service" "psc_neg" {
  for_each        = var.backend_services_psc_neg
  provider        = google-beta
  project         = var.project_id
  name            = "${local.prefix}bes-psc-neg-${each.key}"
  protocol        = "HTTP"
  timeout_sec     = "30"
  security_policy = each.value.security_policy
  enable_cdn      = each.value.enable_cdn
  health_checks   = [google_compute_health_check.http_neg[each.key].self_link]
  dynamic "backend" {
    for_each = { for b in each.value.backends : b.group => b }
    iterator = backend
    content {
      group                 = backend.key
      balancing_mode        = try(backend.value.balancing_mode, "RATE")
      max_rate_per_endpoint = try(backend.value.max_rate_per_endpoint, 5)
    }
  }
  custom_request_headers = [
    "X-CDN-Cache-ID:{cdn_cache_id}",
    "X-CDN-Cache-Status:{cdn_cache_status}",
    "X-Origin-Request-Header:{origin_request_header}",
    "X-Client-RTT-msec:{client_rtt_msec}",
    "X-Client-Region:{client_region}",
    "X-Client-Region-Subdivision:{client_region_subdivision}",
    "X-Client-City:{client_region},{client_city}",
    "X-Client-City-Lat-Long:{client_city_lat_long}",
    "X-TLS-SNI-Hostname:{tls_sni_hostname}",
    "X-TLS-Version:{tls_version}",
    "X-TLS-Cipher-Suite:{tls_cipher_suite}",
  ]
  log_config {
    enable      = true
    sample_rate = 1
  }
}
