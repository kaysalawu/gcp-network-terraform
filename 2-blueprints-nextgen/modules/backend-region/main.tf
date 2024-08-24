
locals {
  prefix = var.prefix == "" ? "" : join("-", [var.prefix, ""])
}

# health check
#---------------------------------

# mig

resource "google_compute_region_health_check" "http_mig" {
  for_each            = var.backend_services_mig
  provider            = google-beta
  project             = var.project_id
  name                = "${local.prefix}http-mig-${each.key}"
  region              = var.region
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

resource "google_compute_region_health_check" "http_neg" {
  for_each            = var.backend_services_neg
  provider            = google-beta
  project             = var.project_id
  name                = "${local.prefix}http-neg-${each.key}"
  region              = var.region
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

resource "google_compute_region_backend_service" "mig" {
  for_each              = var.backend_services_mig
  provider              = google-beta
  project               = var.project_id
  name                  = "${local.prefix}bes-mig-${each.key}"
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = "10"
  health_checks         = [google_compute_region_health_check.http_mig[each.key].self_link]
  port_name             = each.value.port_name
  dynamic "backend" {
    for_each = { for b in each.value.backends : b.group => b }
    iterator = backend
    content {
      group                 = backend.key
      balancing_mode        = try(backend.value.balancing_mode, "RATE")
      max_rate_per_instance = try(backend.value.max_rate_per_endpoint, 100)
      capacity_scaler       = try(backend.value.capacity_scaler, 1.0)
    }
  }
  log_config {
    enable      = true
    sample_rate = 1
  }
}

# neg

resource "google_compute_region_backend_service" "neg" {
  for_each              = var.backend_services_neg
  provider              = google-beta
  project               = var.project_id
  name                  = "${local.prefix}bes-neg-${each.key}"
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = "10"
  health_checks         = [google_compute_region_health_check.http_neg[each.key].self_link]
  dynamic "backend" {
    for_each = { for b in each.value.backends : b.group => b }
    iterator = backend
    content {
      group                 = backend.key
      balancing_mode        = try(backend.value.balancing_mode, "RATE")
      max_rate_per_endpoint = try(backend.value.max_rate_per_endpoint, 5)
      capacity_scaler       = try(backend.value.capacity_scaler, 1.0)
    }
  }
  log_config {
    enable      = true
    sample_rate = 1
  }
}

# psc neg

resource "google_compute_region_backend_service" "psc_neg" {
  for_each              = var.backend_services_psc_neg
  provider              = google-beta
  project               = var.project_id
  name                  = "${local.prefix}bes-psc-neg-${each.key}"
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  dynamic "backend" {
    for_each = { for b in each.value.backends : b.group => b }
    iterator = backend
    content {
      group           = backend.key
      balancing_mode  = try(backend.value.balancing_mode, "RATE")
      capacity_scaler = try(backend.value.capacity_scaler, 1.0)
    }
  }
  log_config {
    enable      = true
    sample_rate = 1
  }
}
