# L7 XLB

This module creates a L7 XLB.

## Example

### HTTP L7 XLB with MIG and NEG

L7 ILB module
```
module "xlb7" {
  source     = "./modules/xlb7"
  project_id = var.project_id
  name       = "xlb7"
  network    = google_compute_network.vpc.self_link
  frontend = {
    port          = 80
    ssl           = { self_cert = false, domains = local.ssl_cert_domains }
    standard_tier = { enable = false, region = local.eu_region }
  }
  mig_config = {
    port_name = local.svc_web.name
    backends = [
      {
        group          = google_compute_instance_group.eu_xlb7_ig.self_link
        balancing_mode = "UTILIZATION", capacity_scaler = 1.0
      },
      {
        group          = google_compute_instance_group.us_xlb7_ig.self_link
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
        group                 = data.google_compute_network_endpoint_group.eu_xlb7_hybrid_neg.id
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
  url_map = google_compute_url_map.xlb7_url_map.id
}
```

URL Map
```
resource "google_compute_url_map" "xlb7_url_map" {
  provider        = google-beta
  project         = var.project_id
  name            = "xlb7-url-map"
  default_service = module.xlb7.backend_service_mig.self_link
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
      service = module.xlb7.backend_service_mig.self_link
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
      service = module.xlb7.backend_service_neg.self_link
    }
    default_service = module.xlb7.backend_service_mig.self_link
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_address"></a> [address](#input\_address) | Optional IP address used for the forwarding rule. | `string` | `null` | no |
| <a name="input_frontend"></a> [frontend](#input\_frontend) | n/a | <pre>object({<br>    regional = object({<br>      enable = bool<br>      region = string<br>    })<br>    ssl = object({<br>      self_cert = bool<br>      domains   = list(string)<br>    })<br>  })</pre> | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels set on resources. | `map(string)` | `{}` | no |
| <a name="input_network"></a> [network](#input\_network) | Network used for resources. | `string` | n/a | yes |
| <a name="input_port_range"></a> [port\_range](#input\_port\_range) | Port used for forwarding rule. | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix used for all resources. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id where resources will be created. | `string` | n/a | yes |
| <a name="input_protocol"></a> [protocol](#input\_protocol) | IP protocol used, defaults to TCP. | `string` | `"TCP"` | no |
| <a name="input_service_label"></a> [service\_label](#input\_service\_label) | Optional prefix of the fully qualified forwarding rule name. | `string` | `null` | no |
| <a name="input_url_map"></a> [url\_map](#input\_url\_map) | url map | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_forwarding_rule"></a> [forwarding\_rule](#output\_forwarding\_rule) | Forwarding rule resource. |
<!-- END_TF_DOCS -->
