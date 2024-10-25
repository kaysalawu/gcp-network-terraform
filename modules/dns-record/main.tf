/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  managed_zone = data.google_dns_managed_zone.dns_managed_zone
  # split record name and type and set as keys in a map
  _recordsets_0 = {
    for key, attrs in var.recordsets :
    key => merge(attrs, zipmap(["type", "name"], split(" ", key)))
  }
  # compute the final resource name for the recordset
  recordsets = {
    for key, attrs in local._recordsets_0 :
    key => merge(attrs, {
      resource_name = (
        attrs.name == ""
        ? local.managed_zone.dns_name
        : (
          substr(attrs.name, -1, 1) == "."
          ? attrs.name
          : "${attrs.name}.${local.managed_zone.dns_name}"
        )
      )
    })
  }
}

data "google_dns_managed_zone" "dns_managed_zone" {
  project = var.project_id
  name    = var.name
}

resource "google_dns_record_set" "dns_record_set" {
  for_each     = local.recordsets
  project      = var.project_id
  managed_zone = var.name
  name         = each.value.resource_name
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.records

  dynamic "routing_policy" {
    for_each = (each.value.geo_routing != null || each.value.wrr_routing != null) ? [""] : []
    content {
      dynamic "geo" {
        for_each = coalesce(each.value.geo_routing, [])
        content {
          location = geo.value.location
          rrdatas  = geo.value.records
          dynamic "health_checked_targets" {
            for_each = try(geo.value.health_checked_targets, null) == null ? [] : [""]
            content {
              dynamic "internal_load_balancers" {
                for_each = geo.value.health_checked_targets
                content {
                  load_balancer_type = internal_load_balancers.value.load_balancer_type
                  ip_address         = internal_load_balancers.value.ip_address
                  port               = internal_load_balancers.value.port
                  ip_protocol        = internal_load_balancers.value.ip_protocol
                  network_url        = internal_load_balancers.value.network_url
                  project            = internal_load_balancers.value.project
                  region             = internal_load_balancers.value.region
                }
              }
            }
          }
        }
      }
      dynamic "wrr" {
        for_each = coalesce(each.value.wrr_routing, [])
        content {
          weight  = wrr.value.weight
          rrdatas = wrr.value.records
        }
      }
    }
  }
}
