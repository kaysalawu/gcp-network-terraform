<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_address"></a> [address](#input\_address) | Optional IP address used for the forwarding rule. | `string` | `null` | no |
| <a name="input_backend_config"></a> [backend\_config](#input\_backend\_config) | Optional backend configuration. | <pre>object({<br>    session_affinity                = string<br>    timeout_sec                     = number<br>    connection_draining_timeout_sec = number<br>  })</pre> | `null` | no |
| <a name="input_backends"></a> [backends](#input\_backends) | Load balancer backends, balancing mode is one of 'CONNECTION' or 'UTILIZATION'. | <pre>list(object({<br>    failover       = bool<br>    group          = string<br>    balancing_mode = string<br>  }))</pre> | n/a | yes |
| <a name="input_failover_config"></a> [failover\_config](#input\_failover\_config) | Optional failover configuration. | <pre>object({<br>    disable_connection_drain  = bool<br>    drop_traffic_if_unhealthy = bool<br>    ratio                     = number<br>  })</pre> | `null` | no |
| <a name="input_global_access"></a> [global\_access](#input\_global\_access) | Global access, defaults to false if not set. | `bool` | `null` | no |
| <a name="input_group_configs"></a> [group\_configs](#input\_group\_configs) | Optional unmanaged groups to create. Can be referenced in backends via outputs. | <pre>map(object({<br>    instances   = list(string)<br>    named_ports = map(number)<br>    zone        = string<br>  }))</pre> | `{}` | no |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check) | Name of existing health check to use, disables auto-created health check. | `string` | `null` | no |
| <a name="input_health_check_config"></a> [health\_check\_config](#input\_health\_check\_config) | Configuration of the auto-created helth check. | <pre>object({<br>    type    = string      # http https tcp ssl http2<br>    check   = map(any)    # actual health check block attributes<br>    config  = map(number) # interval, thresholds, timeout<br>    logging = bool<br>  })</pre> | <pre>{<br>  "check": {<br>    "port_specification": "USE_SERVING_PORT"<br>  },<br>  "config": {},<br>  "logging": false,<br>  "type": "http"<br>}</pre> | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels set on resources. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Name used for all resources. | `string` | n/a | yes |
| <a name="input_ports"></a> [ports](#input\_ports) | Comma-separated ports, leave null to use all ports. | `list(string)` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id where resources will be created. | `string` | n/a | yes |
| <a name="input_protocol"></a> [protocol](#input\_protocol) | IP protocol used, defaults to TCP. | `string` | `"TCP"` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region. | `string` | n/a | yes |
| <a name="input_service_label"></a> [service\_label](#input\_service\_label) | Optional prefix of the fully qualified forwarding rule name. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend"></a> [backend](#output\_backend) | Backend resource. |
| <a name="output_backend_id"></a> [backend\_id](#output\_backend\_id) | Backend id. |
| <a name="output_backend_self_link"></a> [backend\_self\_link](#output\_backend\_self\_link) | Backend self link. |
| <a name="output_forwarding_rule"></a> [forwarding\_rule](#output\_forwarding\_rule) | Forwarding rule resource. |
| <a name="output_forwarding_rule_address"></a> [forwarding\_rule\_address](#output\_forwarding\_rule\_address) | Forwarding rule address. |
| <a name="output_forwarding_rule_id"></a> [forwarding\_rule\_id](#output\_forwarding\_rule\_id) | Forwarding rule id. |
| <a name="output_forwarding_rule_self_link"></a> [forwarding\_rule\_self\_link](#output\_forwarding\_rule\_self\_link) | Forwarding rule self link. |
| <a name="output_group_self_links"></a> [group\_self\_links](#output\_group\_self\_links) | Optional unmanaged instance group self links. |
| <a name="output_groups"></a> [groups](#output\_groups) | Optional unmanaged instance group resources. |
| <a name="output_health_check"></a> [health\_check](#output\_health\_check) | Auto-created health-check resource. |
| <a name="output_health_check_self_id"></a> [health\_check\_self\_id](#output\_health\_check\_self\_id) | Auto-created health-check self id. |
| <a name="output_health_check_self_link"></a> [health\_check\_self\_link](#output\_health\_check\_self\_link) | Auto-created health-check self link. |
<!-- END_TF_DOCS -->