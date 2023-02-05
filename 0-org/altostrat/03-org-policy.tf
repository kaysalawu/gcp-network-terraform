
# org policies

locals {
  constraints_boolean = {
    ("compute.requireShieldedVm")            = { "enforce" = true }
    ("compute.requireOsLogin")               = { "enforce" = true }
    ("iam.disableServiceAccountKeyCreation") = { "enforce" = false }
  }
  constraints_list_all = {
    ("compute.vmCanIpForward")     = { "enforce" = false }
    ("compute.restrictVpnPeerIPs") = { "enforce" = false }
    ("compute.restrictVpcPeering") = { "enforce" = false }
  }
  constraints_list_values = {}
}

module "org_policy_constraints_boolean" {
  for_each        = local.constraints_boolean
  source          = "terraform-google-modules/org-policy/google"
  version         = "~> 3.0.2"
  constraint      = each.key
  policy_type     = "boolean"
  policy_for      = "organization"
  organization_id = var.organization_id
  enforce         = each.value.enforce
  #exclude_folders  = ["folders/folder-1-id", "folders/folder-2-id"]
  #exclude_projects = ["project3", "project4"]
}

module "org_policy_constraints_list_all" {
  for_each        = local.constraints_list_all
  source          = "terraform-google-modules/org-policy/google"
  version         = "~> 3.0.2"
  constraint      = each.key
  policy_type     = "list"
  policy_for      = "organization"
  organization_id = var.organization_id
  enforce         = each.value.enforce
  #exclude_folders  = ["folders/folder-1-id", "folders/folder-2-id"]
  #exclude_projects = ["project3", "project4"]
}

/*
resource "google_organization_policy" "constraints_boolean" {
  for_each   = local.constraints_boolean
  org_id     = var.organization_id
  constraint = each.key
  boolean_policy {
    enforce = each.value.enforce
  }
}

resource "google_organization_policy" "constraints_list" {
  for_each   = local.constraints_list_all
  org_id     = var.organization_id
  constraint = each.key
  list_policy {
    allow {
      all = try(!each.value.enforce, null)
    }
  }
}*/
