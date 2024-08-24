
# security policy - backend
#----------------------------------------------------

locals {
  hub_xlb7_backend_sec_policy = "${local.hub_prefix}backend-policy"
  hub_xlb7_backend_sec_yaml = templatefile("../../templates/armor/policy/policy.yaml", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_backend_sec_policy
    RULES       = local.hub_xlb7_sec_rules
    TYPE        = "CLOUD_ARMOR"
  })
  hub_xlb7_backend_sec_rules_create = templatefile("../../templates/armor/policy/create.sh", {
    PROJECT_ID       = var.project_id_hub
    POLICY_NAME      = local.hub_xlb7_backend_sec_policy
    POLICY_FILE_NAME = "${local.hub_prefix}owasp-backend.yaml"
    POLICY_FILE_DIR  = "output/armor"
    POLICY_FILE_YAML = local.hub_xlb7_backend_sec_yaml
  })
  hub_xlb7_backend_sec_rules_delete = templatefile("../../templates/armor/policy/delete.sh", {
    PROJECT_ID       = var.project_id_hub
    POLICY_NAME      = local.hub_xlb7_backend_sec_policy
    POLICY_FILE_NAME = "${local.hub_prefix}owasp-backend.yaml"
    POLICY_FILE_DIR  = "output/armor"
    POLICY_FILE_YAML = local.hub_xlb7_backend_sec_yaml
  })
}

resource "null_resource" "hub_xlb7_backend_sec_policy" {
  triggers = {
    create = local.hub_xlb7_backend_sec_rules_create
    delete = local.hub_xlb7_backend_sec_rules_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

resource "local_file" "hub_xlb7_backend_sec_policy" {
  content  = local.hub_xlb7_backend_sec_yaml
  filename = "output/armor/backend-policy.yaml"
}

# security policy - edge
#----------------------------------------------------

locals {
  hub_xlb7_edge_sec_policy = "${local.hub_prefix}edge-policy"
  hub_xlb7_edge_sec_yaml = templatefile("../../templates/armor/policy/policy.yaml", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
    RULES       = local.hub_xlb7_sec_rules
    TYPE        = "CLOUD_ARMOR_EDGE"
  })
  hub_xlb7_edge_sec_rules_create = templatefile("../../templates/armor/policy/create.sh", {
    PROJECT_ID       = var.project_id_hub
    POLICY_NAME      = local.hub_xlb7_edge_sec_policy
    POLICY_FILE_NAME = "${local.hub_prefix}owasp-edge.yaml"
    POLICY_FILE_DIR  = "output/armor"
    POLICY_FILE_YAML = local.hub_xlb7_edge_sec_yaml
  })
  hub_xlb7_edge_sec_rules_delete = templatefile("../../templates/armor/policy/delete.sh", {
    PROJECT_ID       = var.project_id_hub
    POLICY_NAME      = local.hub_xlb7_edge_sec_policy
    POLICY_FILE_NAME = "${local.hub_prefix}owasp-edge.yaml"
    POLICY_FILE_DIR  = "output/armor"
    POLICY_FILE_YAML = local.hub_xlb7_edge_sec_yaml
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

resource "local_file" "hub_xlb7_edge_sec_policy" {
  content  = local.hub_xlb7_edge_sec_yaml
  filename = "output/armor/edge-policy.yaml"
}
