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
  source                   = "../modules/backend-region"
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
  source           = "../modules/int-lb-app-frontend"
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

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backend_services_mig"></a> [backend\_services\_mig](#input\_backend\_services\_mig) | MIG backend services map. | <pre>map(object({<br>    port_name = string<br>    backends  = list(any)<br>    health_check_config = object({<br>      check   = map(any)    # actual health check block attributes<br>      config  = map(number) # interval, thresholds, timeout<br>      logging = bool<br>    })<br>  }))</pre> | `{}` | no |
| <a name="input_backend_services_neg"></a> [backend\_services\_neg](#input\_backend\_services\_neg) | NEG backend services map. | <pre>map(object({<br>    port     = number<br>    backends = list(any)<br>    health_check_config = object({<br>      check   = map(any)    # actual health check block attributes<br>      config  = map(number) # interval, thresholds, timeout<br>      logging = bool<br>    })<br>  }))</pre> | `{}` | no |
| <a name="input_backend_services_psc_neg"></a> [backend\_services\_psc\_neg](#input\_backend\_services\_psc\_neg) | PSC NEG backend services map. | <pre>map(object({<br>    port     = number<br>    backends = list(any)<br>  }))</pre> | `{}` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels set on resources. | `map(string)` | `{}` | no |
| <a name="input_network"></a> [network](#input\_network) | Network used for resources. | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix used for all resources. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id where resources will be created. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | GCP region used for all resources. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_service_mig"></a> [backend\_service\_mig](#output\_backend\_service\_mig) | Backend resource. |
| <a name="output_backend_service_neg"></a> [backend\_service\_neg](#output\_backend\_service\_neg) | Backend resource. |
| <a name="output_backend_service_psc_neg"></a> [backend\_service\_psc\_neg](#output\_backend\_service\_psc\_neg) | Backend resource. |
<!-- END_TF_DOCS -->
