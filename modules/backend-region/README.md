# L7 XLB

This module creates a L7 ILB with backends in instance groups or network endpoint groups.

## Example

### Regional Backend
```
locals {
  spoke2_us_ilb7_backend_services_mig = {
    ("main") = {
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
    ("psc7") = {
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
  depends_on               = [null_resource.spoke2_us_ilb7_psc_neg]
  source                   = "../../modules/backend-region"
  project_id               = var.project_id_spoke2
  prefix                   = "${local.spoke2_prefix}us-ilb7"
  network                  = google_compute_network.spoke2_vpc.self_link
  region                   = local.spoke2_us_region
  backend_services_mig     = local.spoke2_us_ilb7_backend_services_mig
  backend_services_neg     = local.spoke2_us_ilb7_backend_services_neg
  backend_services_psc_neg = local.spoke2_us_ilb7_backend_services_psc_neg
}
```

# URL Map

```
resource "google_compute_region_url_map" "spoke2_us_ilb7_url_map" {
  provider        = google-beta
  project         = var.project_id_spoke2
  name            = "${local.spoke2_prefix}us-ilb7-url-map"
  region          = local.spoke2_us_region
  default_service = module.spoke2_us_ilb7_bes.backend_service_mig["main"].id
  host_rule {
    path_matcher = "main"
    hosts        = ["${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}"]
  }
  host_rule {
    path_matcher = "psc7"
    hosts        = [local.spoke2_us_psc_https_ctrl_dns]
  }
  path_matcher {
    name            = "main"
    default_service = module.spoke2_us_ilb7_bes.backend_service_mig["main"].self_link
  }
  path_matcher {
    name            = "psc7"
    default_service = module.spoke2_us_ilb7_bes.backend_service_psc_neg["psc7"].self_link
  }
}
```

# Frontend (HTTP and HTTPS)
```
module "spoke2_us_ilb7_frontend" {
  source           = "../../modules/ilb7-frontend"
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
      port    = 80

    }
    https = {
      enable   = true
      address  = local.spoke2_us_ilb7_https_addr
      port     = 443
      ssl      = { self_cert = true, domains = local.spoke2_us_ilb7_domains }
      redirect = { enable = false, redirected_port = local.svc_web.port }
    }
  }
}
```

## Variables

### Requirements

No requirements.

### Providers

| Name | Version |
|------|---------|
| google | n/a |
| google-beta | n/a |
| tls | n/a |

### Modules

No Modules.

### Resources

| Name |
|------|
| [google-beta_google_compute_backend_service](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_backend_service) |
| [google-beta_google_compute_forwarding_rule](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_forwarding_rule) |
| [google-beta_google_compute_global_forwarding_rule](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_global_forwarding_rule) |
| [google-beta_google_compute_health_check](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_health_check) |
| [google-beta_google_compute_managed_ssl_certificate](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_managed_ssl_certificate) |
| [google-beta_google_compute_target_http_proxy](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_target_http_proxy) |
| [google_compute_address](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) |
| [google_compute_global_address](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) |
| [google_compute_ssl_certificate](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ssl_certificate) |
| [google_compute_ssl_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ssl_policy) |
| [google_compute_target_https_proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy) |
| [tls_cert_request](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) |
| [tls_locally_signed_cert](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) |
| [tls_private_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) |
| [tls_self_signed_cert](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| address | Optional IP address used for the forwarding rule. | `string` | `null` | no |
| backend\_config | Optional backend configuration. | <pre>object({<br>    session_affinity                = string<br>    timeout_sec                     = number<br>    connection_draining_timeout_sec = number<br>  })</pre> | `null` | no |
| frontend | n/a | <pre>object({<br>    port = number<br>    standard_tier = object({<br>      enable = bool<br>      region = string<br>    })<br>    ssl = object({<br>      self_cert = bool<br>      domains   = list(string)<br>    })<br>  })</pre> | n/a | yes |
| health\_check | Name of existing health check to use, disables auto-created health check. | `string` | `null` | no |
| health\_check\_config | Configuration of the auto-created helth check. | <pre>object({<br>    type    = string      # http https tcp ssl http2<br>    check   = map(any)    # actual health check block attributes<br>    config  = map(number) # interval, thresholds, timeout<br>    logging = bool<br>  })</pre> | <pre>{<br>  "check": {<br>    "port_specification": "USE_SERVING_PORT"<br>  },<br>  "config": {},<br>  "logging": false,<br>  "type": "http"<br>}</pre> | no |
| instance\_groups | Optional unmanaged groups to create. Can be referenced in backends via outputs. | <pre>map(object({<br>    instances   = list(string)<br>    named_ports = map(number)<br>    zone        = string<br>  }))</pre> | `{}` | no |
| labels | Labels set on resources. | `map(string)` | `{}` | no |
| mig\_config | backend service | <pre>object({<br>    port_name = string<br>    backends  = list(any)<br>    health_check_config = object({<br>      check   = map(any)    # actual health check block attributes<br>      config  = map(number) # interval, thresholds, timeout<br>      logging = bool<br>    })<br>  })</pre> | `null` | no |
| name | Name used for all resources. | `string` | n/a | yes |
| neg\_config | backend service | <pre>object({<br>    port     = number<br>    backends = list(any)<br>    health_check_config = object({<br>      check   = map(any)    # actual health check block attributes<br>      config  = map(number) # interval, thresholds, timeout<br>      logging = bool<br>    })<br>  })</pre> | `null` | no |
| network | Network used for resources. | `string` | n/a | yes |
| port\_range | Port used for forwarding rule. | `string` | `null` | no |
| project\_id | Project id where resources will be created. | `string` | n/a | yes |
| protocol | IP protocol used, defaults to TCP. | `string` | `"TCP"` | no |
| service\_label | Optional prefix of the fully qualified forwarding rule name. | `string` | `null` | no |
| url\_map | url map | `string` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| backend\_service\_mig | Backend resource. |
| backend\_service\_neg | Backend resource. |
| forwarding\_rule | Forwarding rule resource. |
