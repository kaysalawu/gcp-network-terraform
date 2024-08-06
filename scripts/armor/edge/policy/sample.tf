# security policy - edge
#----------------------------------------------------

locals {
  hub_xlb7_edge_sec_policy = "${local.hub_prefix}xlb7-edge-sec-policy"
  hub_xlb7_edge_sec_policy_create = templatefile("../../scripts/armor/edge/policy/create.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
    POLICY_TYPE = "CLOUD_ARMOR_EDGE"
  })
  hub_xlb7_edge_sec_policy_delete = templatefile("../../scripts/armor/edge/policy/delete.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
  })
}

resource "null_resource" "hub_xlb7_edge_sec_policy" {
  triggers = {
    create = local.hub_xlb7_edge_sec_policy_create
    delete = local.hub_xlb7_edge_sec_policy_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}
