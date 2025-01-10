# Google Cloud DNS Module (Updated for customer Reverse lookup))

This module allows simple management of Google Cloud DNS zones and records. It supports creating public, private, forwarding, peering, service directory and reverse-managed based zones. To create inbound/outbound server policies, please have a look at the [net-vpc](../net-vpc/README.md) module.

For DNSSEC configuration, refer to the [`dns_managed_zone` documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone#dnssec_config).

## Examples

### Private Zone

```hcl
module "private-dns" {
  source     = "./fabric/modules/dns"
  project_id = var.project_id
  name       = "test-example"
  zone_config = {
    domain = "test.example."
    private = {
      client_networks = [var.vpc.self_link]
    }
  }
  recordsets = {
    "A localhost" = { records = ["127.0.0.1"] }
    "A myhost"    = { ttl = 600, records = ["10.0.0.120"] }
  }
  iam = {
    "roles/dns.admin" = ["group:${var.group_email}"]
  }
}
# tftest modules=1 resources=4 inventory=private-zone.yaml e2e
```

### Forwarding Zone

```hcl
module "private-dns" {
  source     = "./fabric/modules/dns"
  project_id = var.project_id
  name       = "test-example"
  zone_config = {
    domain = "test.example."
    forwarding = {
      client_networks = [var.vpc.self_link]
      forwarders      = { "10.0.1.1" = null, "1.2.3.4" = "private" }
    }
  }
}
# tftest modules=1 resources=1 inventory=forwarding-zone.yaml e2e
```

### Peering Zone

```hcl
module "private-dns" {
  source     = "./fabric/modules/dns"
  project_id = var.project_id
  name       = "test-example"
  zone_config = {
    domain = "."
    peering = {
      client_networks = [var.vpc.self_link]
      peer_network    = var.vpc2.self_link
    }
  }
}
# tftest modules=1 resources=1 inventory=peering-zone.yaml
```

### Routing Policies

```hcl
module "private-dns" {
  source     = "./fabric/modules/dns"
  project_id = var.project_id
  name       = "test-example"
  zone_config = {
    domain = "test.example."
    private = {
      client_networks = [var.vpc.self_link]
    }
  }
  recordsets = {
    "A regular" = { records = ["10.20.0.1"] }
    "A geo1" = {
      geo_routing = [
        { location = "europe-west1", records = ["10.0.0.1"] },
        { location = "europe-west2", records = ["10.0.0.2"] },
        { location = "europe-west3", records = ["10.0.0.3"] }
      ]
    }
    "A geo2" = {
      geo_routing = [
        { location = var.region, health_checked_targets = [
          {
            load_balancer_type = "globalL7ilb"
            ip_address         = module.net-lb-app-int-cross-region.addresses[var.region]
            port               = "80"
            ip_protocol        = "tcp"
            network_url        = var.vpc.self_link
            project            = var.project_id
          }
        ] }
      ]
    }
    "A wrr" = {
      ttl = 600
      wrr_routing = [
        { weight = 0.6, records = ["10.10.0.1"] },
        { weight = 0.2, records = ["10.10.0.2"] },
        { weight = 0.2, records = ["10.10.0.3"] }
      ]
    }
  }
}
# tftest modules=4 resources=12 fixtures=fixtures/net-lb-app-int-cross-region.tf,fixtures/compute-mig.tf inventory=routing-policies.yaml e2e
```

### Reverse Lookup Zone

```hcl
module "private-dns" {
  source     = "./fabric/modules/dns"
  project_id = var.project_id
  name       = "test-example"
  zone_config = {
    domain = "0.0.10.in-addr.arpa."
    private = {
      client_networks = [var.vpc.self_link]
    }
  }
}
# tftest modules=1 resources=1 inventory=reverse-zone.yaml e2e
```

### Public Zone

```hcl
module "public-dns" {
  source     = "./fabric/modules/dns"
  project_id = var.project_id
  name       = "test-example"
  zone_config = {
    domain = "test.example."
    public = {}
  }
  recordsets = {
    "A myhost" = { ttl = 300, records = ["127.0.0.1"] }
  }
  iam = {
    "roles/dns.admin" = ["group:${var.group_email}"]
  }
}
# tftest modules=1 resources=3 inventory=public-zone.yaml e2e
```
<!-- BEGIN TFDOC -->
## Variables

| name | description | type | required | default |
|---|---|:---:|:---:|:---:|
| [name](variables.tf#L35) | Zone name, must be unique within the project. | <code>string</code> | ✓ |  |
| [project_id](variables.tf#L40) | Project id for the zone. | <code>string</code> | ✓ |  |
| [description](variables.tf#L17) | Domain description. | <code>string</code> |  | <code>&#34;Terraform managed.&#34;</code> |
| [force_destroy](variables.tf#L23) | Set this to true to delete all records in the zone upon zone destruction. | <code>bool</code> |  | <code>null</code> |
| [iam](variables.tf#L29) | IAM bindings in {ROLE => [MEMBERS]} format. | <code>map&#40;list&#40;string&#41;&#41;</code> |  | <code>null</code> |
| [recordsets](variables.tf#L45) | Map of DNS recordsets in \"type name\" => {ttl, [records]} format. | <code title="map&#40;object&#40;&#123;&#10;  ttl     &#61; optional&#40;number, 300&#41;&#10;  records &#61; optional&#40;list&#40;string&#41;&#41;&#10;  geo_routing &#61; optional&#40;list&#40;object&#40;&#123;&#10;    location &#61; string&#10;    records  &#61; optional&#40;list&#40;string&#41;&#41;&#10;    health_checked_targets &#61; optional&#40;list&#40;object&#40;&#123;&#10;      load_balancer_type &#61; string&#10;      ip_address         &#61; string&#10;      port               &#61; string&#10;      ip_protocol        &#61; string&#10;      network_url        &#61; string&#10;      project            &#61; string&#10;      region             &#61; optional&#40;string&#41;&#10;    &#125;&#41;&#41;&#41;&#10;  &#125;&#41;&#41;&#41;&#10;  wrr_routing &#61; optional&#40;list&#40;object&#40;&#123;&#10;    weight  &#61; number&#10;    records &#61; list&#40;string&#41;&#10;  &#125;&#41;&#41;&#41;&#10;&#125;&#41;&#41;">map&#40;object&#40;&#123;&#8230;&#125;&#41;&#41;</code> |  | <code>&#123;&#125;</code> |
| [zone_config](variables.tf#L102) | DNS zone configuration. | <code title="object&#40;&#123;&#10;  domain &#61; string&#10;  forwarding &#61; optional&#40;object&#40;&#123;&#10;    forwarders      &#61; optional&#40;map&#40;string&#41;&#41;&#10;    client_networks &#61; list&#40;string&#41;&#10;  &#125;&#41;&#41;&#10;  peering &#61; optional&#40;object&#40;&#123;&#10;    client_networks &#61; list&#40;string&#41;&#10;    peer_network    &#61; string&#10;  &#125;&#41;&#41;&#10;  public &#61; optional&#40;object&#40;&#123;&#10;    dnssec_config &#61; optional&#40;object&#40;&#123;&#10;      non_existence &#61; optional&#40;string, &#34;nsec3&#34;&#41;&#10;      state         &#61; string&#10;      key_signing_key &#61; optional&#40;object&#40;&#10;        &#123; algorithm &#61; string, key_length &#61; number &#125;&#41;,&#10;        &#123; algorithm &#61; &#34;rsasha256&#34;, key_length &#61; 2048 &#125;&#10;      &#41;&#10;      zone_signing_key &#61; optional&#40;object&#40;&#10;        &#123; algorithm &#61; string, key_length &#61; number &#125;&#41;,&#10;        &#123; algorithm &#61; &#34;rsasha256&#34;, key_length &#61; 1024 &#125;&#10;      &#41;&#10;    &#125;&#41;&#41;&#10;    enable_logging &#61; optional&#40;bool, false&#41;&#10;  &#125;&#41;&#41;&#10;  private &#61; optional&#40;object&#40;&#123;&#10;    client_networks             &#61; list&#40;string&#41;&#10;    service_directory_namespace &#61; optional&#40;string&#41;&#10;  &#125;&#41;&#41;&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |  | <code>null</code> |

## Outputs

| name | description | sensitive |
|---|---|:---:|
| [dns_keys](outputs.tf#L17) | DNSKEY and DS records of DNSSEC-signed managed zones. |  |
| [domain](outputs.tf#L22) | The DNS zone domain. |  |
| [id](outputs.tf#L27) | Fully qualified zone id. |  |
| [name](outputs.tf#L32) | The DNS zone name. |  |
| [name_servers](outputs.tf#L37) | The DNS zone name servers. |  |
| [zone](outputs.tf#L42) | DNS zone resource. |  |

## Fixtures

- [compute-mig.tf](../../tests/fixtures/compute-mig.tf)
- [net-lb-app-int-cross-region.tf](../../tests/fixtures/net-lb-app-int-cross-region.tf)
<!-- END TFDOC -->

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_description"></a> [description](#input\_description) | Domain description. | `string` | `"Terraform managed."` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Set this to true to delete all records in the zone upon zone destruction. | `bool` | `null` | no |
| <a name="input_iam"></a> [iam](#input\_iam) | IAM bindings in {ROLE => [MEMBERS]} format. | `map(list(string))` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Zone name, must be unique within the project. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id for the zone. | `string` | n/a | yes |
| <a name="input_recordsets"></a> [recordsets](#input\_recordsets) | Map of DNS recordsets in "type name" => {ttl, [records]} format. | <pre>map(object({<br>    ttl     = optional(number, 300)<br>    records = optional(list(string))<br>    geo_routing = optional(list(object({<br>      location = string<br>      records  = optional(list(string))<br>      health_checked_targets = optional(list(object({<br>        load_balancer_type = string<br>        ip_address         = string<br>        port               = string<br>        ip_protocol        = string<br>        network_url        = string<br>        project            = string<br>        region             = optional(string)<br>      })))<br>    })))<br>    wrr_routing = optional(list(object({<br>      weight  = number<br>      records = list(string)<br>    })))<br>  }))</pre> | `{}` | no |
| <a name="input_zone_config"></a> [zone\_config](#input\_zone\_config) | DNS zone configuration. | <pre>object({<br>    domain = string<br>    forwarding = optional(object({<br>      forwarders      = optional(map(string))<br>      client_networks = list(string)<br>    }))<br>    peering = optional(object({<br>      client_networks = list(string)<br>      peer_network    = string<br>    }))<br>    public = optional(object({<br>      dnssec_config = optional(object({<br>        non_existence = optional(string, "nsec3")<br>        state         = string<br>        key_signing_key = optional(object(<br>          { algorithm = string, key_length = number }),<br>          { algorithm = "rsasha256", key_length = 2048 }<br>        )<br>        zone_signing_key = optional(object(<br>          { algorithm = string, key_length = number }),<br>          { algorithm = "rsasha256", key_length = 1024 }<br>        )<br>      }))<br>      enable_logging = optional(bool, false)<br>    }))<br>    private = optional(object({<br>      client_networks             = list(string)<br>      service_directory_namespace = optional(string)<br>    }))<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dns_keys"></a> [dns\_keys](#output\_dns\_keys) | DNSKEY and DS records of DNSSEC-signed managed zones. |
| <a name="output_domain"></a> [domain](#output\_domain) | The DNS zone domain. |
| <a name="output_id"></a> [id](#output\_id) | Fully qualified zone id. |
| <a name="output_name"></a> [name](#output\_name) | The DNS zone name. |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | The DNS zone name servers. |
| <a name="output_zone"></a> [zone](#output\_zone) | DNS zone resource. |
<!-- END_TF_DOCS -->
