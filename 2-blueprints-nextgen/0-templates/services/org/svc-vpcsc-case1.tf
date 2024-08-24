
# 1. https://cloud.google.com/vpc-service-controls/docs/troubleshooting#requests-between-perimeters

# case1 (all blueprints except nva)
#------------------------------------------------------------
# hub perimeter:
#   - egress: site1-sa, hub-sa, spoke1-sa > spoke1 (storage, ai)
#   - egress: site2-sa, hub-sa > spoke2 (storage, ai)
#   - ingress: spoke1-sa > hub (storage, ai) [1]
#   - ingress: spoke2-sa > hub (storage, ai) [1]
#   - ingress: access-level (public ip) > hub (storage, ai)
# spoke1 perimeter:
#   - ingress: hub-project/site1-sa > spoke1 (storage, ai)
#   - ingress: host-project/spoke1-sa > spoke1 (storage, ai)
#   - ingress: access-level (public ip) > spoke1 (storage, ai)
# spoke2 perimeter:
#   - ingress: hub-project/site2-sa > spoke2 (storage) # ingress/egress between 2 perimeters will not work [1]
#------------------------------------------------------------

# data
#---------------------------------

data "external" "case1_external_ipv4" {
  program = ["sh", "../scripts/general/external-ipv4.sh"]
}

data "external" "case1_external_ipv6" {
  program = ["sh", "../scripts/general/external-ipv6.sh"]
}

# policy
#---------------------------------

locals {
  case1_policy_title = "${local.prefix}-case1-policy"
}

resource "google_access_context_manager_access_policy" "case1_policy" {
  parent = "organizations/${var.organization_id}"
  title  = local.case1_policy_title
}

# access levels
#---------------------------------

locals {
  case1_access_level_title = "${local.prefix}_case1_access_level"
  case1_access_level_name  = "${local.prefix}_case1_access_level"
  case1_access_level_ip    = [data.external.case1_external_ipv4.result.ip, data.external.case1_external_ipv6.result.ip, ]
}

resource "google_access_context_manager_access_level" "case1_access_level" {
  parent = "accessPolicies/${google_access_context_manager_access_policy.case1_policy.name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.case1_policy.name}/accessLevels/${local.case1_access_level_name}"
  title  = local.case1_access_level_title
  basic {
    combining_function = "OR"
    conditions {
      ip_subnetworks = local.case1_access_level_ip
    }
  }
}

locals {
  case1_dry_run = false
  /*case1_accessible_services = ["storage.googleapis.com", "bigquery.googleapis.com", "aiplatform.googleapis.com"]
  case1_restricted_services = [
    { service = "storage.googleapis.com", method = "*" },
    { service = "bigquery.googleapis.com", method = "*" },
    { service = "aiplatform.googleapis.com", method = "*" },
  ]
  case1_restricted_services_list = [for x in local.case1_restricted_services : x.service]*/
  case1_accessible_services      = []
  case1_restricted_services      = []
  case1_restricted_services_list = []
}

# hub
#---------------------------------

resource "google_access_context_manager_service_perimeter" "case1_hub" {
  parent         = "accessPolicies/${google_access_context_manager_access_policy.case1_policy.name}"
  name           = "accessPolicies/${google_access_context_manager_access_policy.case1_policy.name}/servicePerimeters/${local.prefix}_case1_hub"
  title          = "${local.prefix}_case1_hub"
  perimeter_type = "PERIMETER_TYPE_REGULAR"
  status {
    resources           = ["projects/${data.google_project.hub_project_number.number}"]
    restricted_services = local.case1_dry_run ? [] : local.case1_restricted_services_list
    vpc_accessible_services {
      enable_restriction = true
      allowed_services   = local.case1_accessible_services
    }
    egress_policies {
      egress_from {
        identities = ["serviceAccount:${module.site1_sa.email}", "serviceAccount:${module.hub_sa.email}", ]
      }
      egress_to {
        resources = ["projects/${data.google_project.spoke1_project_number.number}"]
        dynamic "operations" {
          for_each = local.case1_restricted_services
          iterator = operation
          content {
            service_name = operation.value.service
            method_selectors { method = operation.value.method }
          }
        }
      }
    }
    egress_policies {
      egress_from {
        identities = ["serviceAccount:${module.site2_sa.email}", "serviceAccount:${module.hub_sa.email}", ]
      }
      egress_to {
        resources = ["projects/${data.google_project.spoke2_project_number.number}"]
        dynamic "operations" {
          for_each = local.case1_restricted_services
          iterator = operation
          content {
            service_name = operation.value.service
            method_selectors { method = operation.value.method }
          }
        }
      }
    }
    ingress_policies {
      ingress_from {
        identities = ["serviceAccount:${module.spoke1_sa.email}", ]
        sources {
          access_level = "*"
        }
      }
      ingress_to {
        resources = ["projects/${data.google_project.hub_project_number.number}"]
        dynamic "operations" {
          for_each = local.case1_restricted_services
          iterator = operation
          content {
            service_name = operation.value.service
            method_selectors { method = operation.value.method }
          }
        }
      }
    }
    ingress_policies {
      ingress_from {
        identities = ["serviceAccount:${module.spoke2_sa.email}", ]
        sources {
          access_level = "*"
        }
      }
      ingress_to {
        resources = ["projects/${data.google_project.hub_project_number.number}"]
        dynamic "operations" {
          for_each = local.case1_restricted_services
          iterator = operation
          content {
            service_name = operation.value.service
            method_selectors { method = operation.value.method }
          }
        }
      }
    }
    ingress_policies {
      ingress_from {
        identity_type = "ANY_IDENTITY"
        sources {
          access_level = google_access_context_manager_access_level.case1_access_level.name
        }
      }
      ingress_to {
        resources = ["projects/${data.google_project.hub_project_number.number}"]
        dynamic "operations" {
          for_each = local.case1_restricted_services
          iterator = operation
          content {
            service_name = operation.value.service
            method_selectors { method = operation.value.method }
          }
        }
      }
    }
  }
}

# spoke1
#---------------------------------

resource "google_access_context_manager_service_perimeter" "case1_spoke1" {
  parent         = "accessPolicies/${google_access_context_manager_access_policy.case1_policy.name}"
  name           = "accessPolicies/${google_access_context_manager_access_policy.case1_policy.name}/servicePerimeters/${local.prefix}_case1_spoke1"
  title          = "${local.prefix}_case1_spoke1"
  perimeter_type = "PERIMETER_TYPE_REGULAR"
  status {
    resources           = ["projects/${data.google_project.spoke1_project_number.number}"]
    restricted_services = local.case1_dry_run ? [] : local.case1_restricted_services_list
    vpc_accessible_services {
      enable_restriction = true
      allowed_services   = local.case1_accessible_services
    }
    egress_policies {
      egress_from {
        identity_type = "ANY_IDENTITY"
      }
      egress_to {
        resources = ["*"]
      }
    }
    ingress_policies {
      ingress_from {
        identities = [
          "serviceAccount:${module.hub_sa.email}",
          "serviceAccount:${module.site1_sa.email}",
        ]
        sources {
          resource = "projects/${data.google_project.hub_project_number.number}"
        }
      }
      ingress_to {
        resources = ["projects/${data.google_project.spoke1_project_number.number}"]
        dynamic "operations" {
          for_each = local.case1_restricted_services
          iterator = operation
          content {
            service_name = operation.value.service
            method_selectors { method = operation.value.method }
          }
        }
      }
    }
    ingress_policies {
      ingress_from {
        identities = [
          "serviceAccount:${module.spoke1_sa.email}",
        ]
        sources {
          resource = "projects/${data.google_project.host_project_number.number}"
        }
      }
      ingress_to {
        resources = ["projects/${data.google_project.spoke1_project_number.number}"]
        dynamic "operations" {
          for_each = local.case1_restricted_services
          iterator = operation
          content {
            service_name = operation.value.service
            method_selectors { method = operation.value.method }
          }
        }
      }
    }
  }
}

# spoke2
#---------------------------------

resource "google_access_context_manager_service_perimeter" "case1_spoke2" {
  parent         = "accessPolicies/${google_access_context_manager_access_policy.case1_policy.name}"
  name           = "accessPolicies/${google_access_context_manager_access_policy.case1_policy.name}/servicePerimeters/${local.prefix}_case1_spoke2"
  title          = "${local.prefix}_case1_spoke2"
  perimeter_type = "PERIMETER_TYPE_REGULAR"
  status {
    resources           = ["projects/${data.google_project.spoke2_project_number.number}"]
    restricted_services = local.case1_dry_run ? [] : local.case1_restricted_services_list
    vpc_accessible_services {
      enable_restriction = true
      allowed_services   = local.case1_accessible_services
    }
    egress_policies {
      egress_from {
        identity_type = "ANY_IDENTITY"
      }
      egress_to {
        resources = ["*"]
      }
    }
    ingress_policies {
      ingress_from {
        identities = [
          "serviceAccount:${module.hub_sa.email}",
          "serviceAccount:${module.site2_sa.email}",
        ]
        sources {
          resource = "projects/${data.google_project.hub_project_number.number}"
        }
      }
      ingress_to {
        resources = ["projects/${data.google_project.spoke2_project_number.number}"]
        dynamic "operations" {
          for_each = local.case1_restricted_services
          iterator = operation
          content {
            service_name = operation.value.service
            method_selectors { method = operation.value.method }
          }
        }
      }
    }
  }
}

# config
#---------------------------------

locals {
  case1_delete = templatefile("../../templates/vpc-sc/perimeter/delete.sh", {
    ORGANIZATION_ID = var.organization_id
    POLICY_TITLE    = google_access_context_manager_access_policy.case1_policy.title
    PERIMETERS = [
      google_access_context_manager_service_perimeter.case1_hub.title,
      google_access_context_manager_service_perimeter.case1_spoke1.title,
      google_access_context_manager_service_perimeter.case1_spoke2.title,
    ]
  })
}

resource "local_file" "case1_delete" {
  content  = local.case1_delete
  filename = "output/vpc-sc/case1/delete.sh"
}

# hub vertex natgw
#---------------------------------

locals {
  hub_eu_vertex_natgw_startup = templatefile("../scripts/startup/natgw.sh", {})
}

module "hub_eu_vertex_natgw" {
  source         = "../modules/compute-vm"
  project_id     = var.project_id_hub
  name           = "${local.hub_prefix}eu-vertex-natgw"
  zone           = "${local.hub_eu_region}-b"
  tags           = [local.tag_ssh, "nat"]
  can_ip_forward = true
  boot_disk = {
    image = var.image_ubuntu
    type  = var.disk_type
    size  = var.disk_size
  }
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses  = null
    nat        = true
    alias_ips  = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_eu_vertex_natgw_startup
}

resource "local_file" "hub_eu_vertex_natgw" {
  content  = module.hub_eu_vertex_natgw.instance.metadata_startup_script
  filename = "output/${local.hub_prefix}eu-vertex-natgw"
}

resource "google_compute_route" "hub_eu_vertex_natgw" {
  provider          = google-beta
  project           = var.project_id_hub
  name              = "${local.hub_prefix}eu-vertex-natgw"
  dest_range        = "0.0.0.0/0"
  network           = google_compute_network.hub_vpc.self_link
  next_hop_instance = module.hub_eu_vertex_natgw.instance.id
  priority          = 90
}

resource "google_compute_route" "hub_eu_vertex_natgw_super" {
  provider         = google-beta
  project          = var.project_id_hub
  name             = "${local.hub_prefix}eu-vertex-natgw-super"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.hub_vpc.self_link
  next_hop_gateway = "default-internet-gateway"
  tags             = ["nat"]
  priority         = 80
}
