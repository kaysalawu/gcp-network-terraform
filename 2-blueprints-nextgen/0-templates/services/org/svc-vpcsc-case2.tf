
# 1. https://cloud.google.com/vpc-service-controls/docs/troubleshooting#requests-between-perimeters
# egress/ingress between 2 perimeters will not work; use perimeter bridges

# case2 (all blueprints except nva)
#------------------------------------------------------------
# hub perimeter:
#   - egress: site1-sa, hub-sa, spoke1-sa > spoke1 (storage, ai)
#   - egress: site2-sa, hub-sa, spoke2-sa > spoke2 (storage, ai)
#   - ingress: access-level (public ip) > hub (storage, ai)
# spoke1 perimeter:
#   - ingress: hub-project/site1-sa > spoke1 (storage, ai)
#   - ingress: hub-project/spoke1-sa > spoke1 (storage, ai)
#   - ingress: access-level (public ip) > spoke1 (storage)
# spoke2 perimeter:
#   - ingress: hub-project/site2-sa > spoke2 (storage, ai) # [1]
#   - ingress: hub-project/spoke2-sa > spoke2 (storage, ai) # [1]
#------------------------------------------------------------

# data
#---------------------------------

data "external" "case2_external_ipv4" {
  program = ["sh", "../scripts/general/external-ipv4.sh"]
}

data "external" "case2_external_ipv6" {
  program = ["sh", "../scripts/general/external-ipv6.sh"]
}

# policy
#---------------------------------

locals {
  case2_policy_title = "${local.prefix}-case2-policy"
}

resource "google_access_context_manager_access_policy" "case2_policy" {
  parent = "organizations/${var.organization_id}"
  title  = local.case2_policy_title
}

# access levels
#---------------------------------

locals {
  case2_access_level_title = "${local.prefix}_case2_access_level"
  case2_access_level_name  = "${local.prefix}_case2_access_level"
  case2_access_level_ip    = [data.external.case2_external_ipv4.result.ip, data.external.case2_external_ipv6.result.ip, ]
}

resource "google_access_context_manager_access_level" "case2_access_level" {
  parent = "accessPolicies/${google_access_context_manager_access_policy.case2_policy.name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.case2_policy.name}/accessLevels/${local.case2_access_level_name}"
  title  = local.case2_access_level_title
  basic {
    combining_function = "OR"
    conditions {
      ip_subnetworks = local.case2_access_level_ip
    }
  }
}

locals {
  case2_dry_run             = false
  case2_accessible_services = ["storage.googleapis.com", "bigquery.googleapis.com", "aiplatform.googleapis.com"]
  case2_restricted_services = [
    { service = "storage.googleapis.com", method = "*" },
    { service = "bigquery.googleapis.com", method = "*" },
    { service = "aiplatform.googleapis.com", method = "*" },
  ]
  case2_restricted_services_list = [for x in local.case2_restricted_services : x.service]
}

# hub
#---------------------------------

resource "google_access_context_manager_service_perimeter" "case2_hub" {
  parent         = "accessPolicies/${google_access_context_manager_access_policy.case2_policy.name}"
  name           = "accessPolicies/${google_access_context_manager_access_policy.case2_policy.name}/servicePerimeters/${local.prefix}_case2_hub"
  title          = "${local.prefix}_case2_hub"
  perimeter_type = "PERIMETER_TYPE_REGULAR"
  status {
    resources           = ["projects/${data.google_project.hub_project_number.number}"]
    restricted_services = local.case2_dry_run ? [] : local.case2_restricted_services_list
    vpc_accessible_services {
      enable_restriction = true
      allowed_services   = local.case2_accessible_services
    }
    egress_policies {
      egress_from {
        identities = [
          "serviceAccount:${module.site1_sa.email}",  # site1 vpn is attached to hub project
          "serviceAccount:${module.spoke1_sa.email}", # spoke1 uses xpn in hub project
          "serviceAccount:${module.hub_sa.email}",    # hub project
        ]
      }
      egress_to {
        resources = ["projects/${data.google_project.spoke1_project_number.number}"]
        dynamic "operations" {
          for_each = local.case2_restricted_services
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
        identities = [
          "serviceAccount:${module.site2_sa.email}",  # site2 vpn is attached to hub project
          "serviceAccount:${module.spoke2_sa.email}", # spoke2 uses xpn in hub project
          "serviceAccount:${module.hub_sa.email}",    # hub project
        ]
      }
      egress_to {
        resources = ["projects/${data.google_project.spoke2_project_number.number}"]
        dynamic "operations" {
          for_each = local.case2_restricted_services
          iterator = operation
          content {
            service_name = operation.value.service
            method_selectors { method = operation.value.method }
          }
        }
      }
    }
    ingress_policies { # [1]
      ingress_from {
        identities = [
          "serviceAccount:${module.spoke1_sa.email}",
          "serviceAccount:${module.spoke2_sa.email}",
        ]
        sources {
          access_level = "*"
        }
      }
      ingress_to {
        resources = ["projects/${data.google_project.hub_project_number.number}"]
        dynamic "operations" {
          for_each = local.case2_restricted_services
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
          access_level = google_access_context_manager_access_level.case2_access_level.name
        }
      }
      ingress_to {
        resources = ["projects/${data.google_project.hub_project_number.number}"]
        dynamic "operations" {
          for_each = local.case2_restricted_services
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

resource "google_access_context_manager_service_perimeter" "case2_spoke1" {
  parent         = "accessPolicies/${google_access_context_manager_access_policy.case2_policy.name}"
  name           = "accessPolicies/${google_access_context_manager_access_policy.case2_policy.name}/servicePerimeters/${local.prefix}_case2_spoke1"
  title          = "${local.prefix}_case2_spoke1"
  perimeter_type = "PERIMETER_TYPE_REGULAR"
  status {
    resources           = ["projects/${data.google_project.spoke1_project_number.number}"]
    restricted_services = local.case2_dry_run ? [] : local.case2_restricted_services_list
    vpc_accessible_services {
      enable_restriction = true
      allowed_services   = local.case2_accessible_services
    }
    /*egress_policies {
      egress_from {
        identity_type = "ANY_IDENTITY"
      }
      egress_to {
        resources = ["*"]
      }
    }*/
    ingress_policies {
      ingress_from {
        identities = [
          "serviceAccount:${module.hub_sa.email}",
          "serviceAccount:${module.site1_sa.email}",
          "serviceAccount:${module.spoke1_sa.email}",
        ]
        sources {
          resource = "projects/${data.google_project.hub_project_number.number}"
        }
      }
      ingress_to {
        resources = ["projects/${data.google_project.spoke1_project_number.number}"]
        dynamic "operations" {
          for_each = local.case2_restricted_services
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

resource "google_access_context_manager_service_perimeter" "case2_spoke2" {
  parent         = "accessPolicies/${google_access_context_manager_access_policy.case2_policy.name}"
  name           = "accessPolicies/${google_access_context_manager_access_policy.case2_policy.name}/servicePerimeters/${local.prefix}_case2_spoke2"
  title          = "${local.prefix}_case2_spoke2"
  perimeter_type = "PERIMETER_TYPE_REGULAR"
  status {
    resources           = ["projects/${data.google_project.spoke2_project_number.number}"]
    restricted_services = local.case2_dry_run ? [] : local.case2_restricted_services_list
    vpc_accessible_services {
      enable_restriction = true
      allowed_services   = local.case2_accessible_services
    }
    /*egress_policies {
      egress_from {
        identity_type = "ANY_IDENTITY"
      }
      egress_to {
        resources = ["*"]
      }
    }*/
    ingress_policies {
      ingress_from {
        identities = [
          "serviceAccount:${module.hub_sa.email}",
          "serviceAccount:${module.site2_sa.email}",
          "serviceAccount:${module.spoke2_sa.email}",
        ]
        sources {
          resource = "projects/${data.google_project.hub_project_number.number}"
        }
      }
      ingress_to {
        resources = ["projects/${data.google_project.spoke2_project_number.number}"]
        dynamic "operations" {
          for_each = local.case2_restricted_services
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
  case2_delete = templatefile("../../templates/vpc-sc/perimeter/delete.sh", {
    ORGANIZATION_ID = var.organization_id
    POLICY_TITLE    = google_access_context_manager_access_policy.case2_policy.title
    PERIMETERS = [
      google_access_context_manager_service_perimeter.case2_hub.title,
      google_access_context_manager_service_perimeter.case2_spoke1.title,
      google_access_context_manager_service_perimeter.case2_spoke2.title,
    ]
  })
}

resource "local_file" "case2_delete" {
  content  = local.case2_delete
  filename = "output/vpc-sc/case2/delete.sh"
}

# hub vertex natgw
#---------------------------------
/*
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
}*/
