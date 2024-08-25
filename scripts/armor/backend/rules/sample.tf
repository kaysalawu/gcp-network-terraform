
# security policy rules
#----------------------------------------------------

locals {
  hub_sec_rule_ip_ranges_allowed_list = [
    "${data.external.case1_external_ip.result.ip}",
    module.hub_eu_attack.external_ip,
    module.hub_eu_adaptive.external_ip,
    module.hub_eu_denied.external_ip,
    module.hub_eu_baseline.external_ip,
  ]
  hub_sec_rule_ip_ranges_allowed_string = join(",", local.hub_sec_rule_ip_ranges_allowed_list)
  hub_xlb7_sec_rule_sqli_excluded_crs = join(",", [
    "'owasp-crs-v030001-id942421-sqli'",
    "'owasp-crs-v030001-id942200-sqli'",
    "'owasp-crs-v030001-id942260-sqli'",
    "'owasp-crs-v030001-id942340-sqli'",
    "'owasp-crs-v030001-id942430-sqli'",
    "'owasp-crs-v030001-id942431-sqli'",
    "'owasp-crs-v030001-id942432-sqli'",
    "'owasp-crs-v030001-id942420-sqli'",
    "'owasp-crs-v030001-id942440-sqli'",
    "'owasp-crs-v030001-id942450-sqli'",
  ])
  hub_xlb7_sec_rule_preconfigured_sqli_tuned = "evaluatePreconfiguredExpr('sqli-stable',[${local.hub_xlb7_sec_rule_sqli_excluded_crs}])"
  hub_xlb7_sec_rule_custom_hacker            = "origin.region_code == 'GB' && request.headers['Referer'].contains('hacker')"
}

# security policy - edge
#----------------------------------------------------

locals {
  hub_xlb7_edge_sec_policy = "${local.hub_prefix}edge-policy"
  hub_xlb7_edge_sec_rules = {
    ("ranges") = { preview = false, priority = 1000, action = "allow", ip = true, src_ip_ranges = join(",", local.hub_sec_rule_ip_ranges_allowed_list) }
    ("default") = { preview = false, priority = 2147483647, action = "deny(403)", ip = true, src_ip_ranges = ["'*'"]
    }
  }
  hub_xlb7_edge_sec_rules_create = templatefile("../../scripts/armor/policy/edge/create.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
    POLICY_TYPE = "CLOUD_ARMOR_EDGE"
    RULES       = local.hub_xlb7_edge_sec_rules
  })
  hub_xlb7_edge_sec_rules_delete = templatefile("../../scripts/armor/policy/edge/delete.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
  })
}

resource "null_resource" "hub_xlb7_edge_sec_policy" {
  triggers = {
    create = local.hub_xlb7_edge_sec_rules_create
    delete = local.hub_xlb7_edge_sec_rules_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}
