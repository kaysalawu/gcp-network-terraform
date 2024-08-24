# HTTP L7 XLB

This module creates a L7 XLB with MIG, NEG and PSC NEG.

## Example

### Backend Service
```
locals {
  hub_xlb7_backend_services_mig = {
    ("good") = {
      port_name       = local.svc_web.name
      enable_cdn      = true
      security_policy = google_compute_security_policy.hub_xlb7_be_sec_policy.name
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
    ("bad") = {
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
    ("goodjuice") = {
      port_name       = local.svc_juice.name
      enable_cdn      = true
      security_policy = google_compute_security_policy.hub_xlb7_be_sec_policy.name
      backends = [
        { group = google_compute_instance_group.hub_eu_xlb7_juice_ig.self_link },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port_specification = "USE_SERVING_PORT" }
      }
    }
    ("badjuice") = {
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
    ("good") = {
      port            = local.svc_web.port
      security_policy = google_compute_security_policy.hub_xlb7_be_sec_policy.name
      enable_cdn      = true
      backends = [
        { group = data.google_compute_network_endpoint_group.hub_eu_xlb7_hybrid_neg.id }
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
}

module "hub_xlb7_bes" {
  source                   = "../modules/backend-global"
  project_id               = var.project_id_hub
  prefix                   = "${local.hub_prefix}xlb7"
  network                  = google_compute_network.hub_vpc.self_link
  backend_services_mig     = local.hub_xlb7_backend_services_mig
  backend_services_neg     = local.hub_xlb7_backend_services_neg
  backend_services_psc_neg = {}
}

module "hub_xlb7_bes_juice" {
  source                   = "../modules/backend-global"
  project_id               = var.project_id_hub
  prefix                   = "${local.hub_prefix}xlb7-juice"
  network                  = google_compute_network.hub_vpc.self_link
  backend_services_mig     = local.hub_xlb7_backend_services_mig_juice
  backend_services_neg     = {}
  backend_services_psc_neg = {}
}
```

### Frontend
```
module "hub_xlb7_frontend" {
  depends_on = [null_resource.hub_xlb7_url_map]
  source     = "../modules/ext-lb-app-frontend"
  project_id = var.project_id_hub
  prefix     = "${local.hub_prefix}xlb7"
  network    = google_compute_network.hub_vpc.self_link
  address    = google_compute_global_address.hub_xlb7_frontend.address
  url_map    = local.hub_xlb7_url_map_name
  frontend = {
    http = {
      enable   = false
      port     = 80
      regional = { enable = false, region = local.hub_eu_region }
    }
    https = {
      enable   = true
      port     = 443
      ssl      = { self_cert = true, domains = local.hub_ssl_cert_domains }
      redirect = { enable = true, redirected_port = 80 }
      regional = { enable = false, region = local.hub_eu_region }
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backend_services_mig"></a> [backend\_services\_mig](#input\_backend\_services\_mig) | MIG backend services map. | <pre>map(object({<br>    port_name       = string<br>    security_policy = string<br>    enable_cdn      = bool<br>    backends        = list(any)<br>    health_check_config = object({<br>      check   = map(any)    # actual health check block attributes<br>      config  = map(number) # interval, thresholds, timeout<br>      logging = bool<br>    })<br>  }))</pre> | `{}` | no |
| <a name="input_backend_services_neg"></a> [backend\_services\_neg](#input\_backend\_services\_neg) | NEG backend services map. | <pre>map(object({<br>    port            = number<br>    security_policy = string<br>    enable_cdn      = bool<br>    backends        = list(any)<br>    health_check_config = object({<br>      check   = map(any)    # actual health check block attributes<br>      config  = map(number) # interval, thresholds, timeout<br>      logging = bool<br>    })<br>  }))</pre> | `{}` | no |
| <a name="input_backend_services_psc_neg"></a> [backend\_services\_psc\_neg](#input\_backend\_services\_psc\_neg) | PSC NEG backend services map. | <pre>map(object({<br>    port     = number<br>    backends = list(any)<br>  }))</pre> | `{}` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels set on resources. | `map(string)` | `{}` | no |
| <a name="input_network"></a> [network](#input\_network) | Network used for resources. | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix used for all resources. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id where resources will be created. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_service_mig"></a> [backend\_service\_mig](#output\_backend\_service\_mig) | Backend resource. |
| <a name="output_backend_service_neg"></a> [backend\_service\_neg](#output\_backend\_service\_neg) | Backend resource. |
| <a name="output_backend_service_psc_neg"></a> [backend\_service\_psc\_neg](#output\_backend\_service\_psc\_neg) | Backend resource. |
<!-- END_TF_DOCS -->
