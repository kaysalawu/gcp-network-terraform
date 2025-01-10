
# case1 (all blueprints except nva)
#------------------------------------------------------------
# hub perimeter:
#   - egress: site1-sa > spoke1 (storage)
#   - egress: site2-sa > spoke2 (storage)
#   - egress: spoke1-sa > spoke1 (storage)
#   - egress: spoke2-sa > spoke2 (storage)
#   - ingress: spoke1-sa > hub (storage,apiplatform)
#   - ingress: spoke2-sa > hub (storage,apiplatform)
#   - ingress: access-level (public ip) > hub (storage,apiplatform)
# spoke1 perimeter:
#   - ingress: hub-project/site1-sa > spoke1 (storage)
#   - ingress: host-project/spoke1-sa > spoke1 (storage)
#   - ingress: access-level (public ip) > spoke1 (storage)
# spoke2 perimeter:
#   - ingress: hub-project/site2-sa > spoke2 (storage)
#------------------------------------------------------------

# data
#---------------------------------

data "external" "case1_external_ip" {
  program = ["sh", "../../scripts/general/external-ip.sh"]
}

# policy
#---------------------------------

locals {
  case1_policy_title = "${local.prefix}-case1-policy"
}

# config

locals {
  case1_restricted_services      = ["storage.googleapis.com", "bigquery.googleapis.com", "aiplatform.googleapis.com"]
  case1_accessible_services      = ["storage.googleapis.com", "bigquery.googleapis.com", "aiplatform.googleapis.com"]
  case1_access_level_ip_prefixes = [data.external.case1_external_ip.result.ip, ]
  case1_access_level = {
    title    = "${local.prefix}_case1_access_level"
    name     = "${local.prefix}_case1_access_level"
    prefixes = local.case1_access_level_ip_prefixes
  }
  case1_perimeters = {
    ("${local.prefix}_case1_hub") = {
      type                = "regular"
      project_numbers     = join(",", [data.google_project.hub_project_number.number])
      restricted_services = join(",", local.case1_restricted_services)
      accessible_services = join(",", local.case1_accessible_services)
      ingress             = []
      egress = [
        {
          from = {
            identities = [
              "serviceAccount:${module.site1_sa.email}",
              "serviceAccount:${module.hub_sa.email}",
            ]
          }
          to = {
            services = local.case1_restricted_services
            methods  = ["\"*\""]
            project  = data.google_project.spoke1_project_number.number
          }
        },
        {
          from = {
            identities = [
              "serviceAccount:${module.site2_sa.email}",
              "serviceAccount:${module.hub_sa.email}",
            ]
          }
          to = {
            services = local.case1_restricted_services
            methods  = ["\"*\""]
            project  = data.google_project.spoke2_project_number.number
          }
        },
      ]
    }
    ("${local.prefix}_case1_spoke1") = {
      type                = "regular"
      project_numbers     = join(",", [data.google_project.spoke1_project_number.number])
      restricted_services = join(",", local.case1_restricted_services)
      accessible_services = join(",", local.case1_accessible_services)
      egress              = []
      ingress = [
        {
          from = {
            identities = [
              "serviceAccount:${module.site1_sa.email}",
              "serviceAccount:${module.hub_sa.email}",
            ]
            project = data.google_project.hub_project_number.number
          }
          to = {
            services = local.case1_restricted_services
            methods  = ["\"*\""]
            project  = data.google_project.spoke1_project_number.number
          }
        },
        {
          from = {
            identities = ["serviceAccount:${module.spoke1_sa.email}"]
            project    = data.google_project.host_project_number.number
          }
          to = {
            services = local.case1_restricted_services
            methods  = ["\"*\""]
            project  = data.google_project.spoke1_project_number.number
          }
        },
      ]
    }
    ("${local.prefix}_case1_spoke2") = {
      type                = "regular"
      project_numbers     = join(",", [data.google_project.spoke2_project_number.number])
      restricted_services = join(",", local.case1_restricted_services)
      accessible_services = join(",", local.case1_accessible_services)
      egress              = []
      ingress = [
        {
          from = {
            identities = [
              "serviceAccount:${module.site2_sa.email}",
              "serviceAccount:${module.hub_sa.email}",
            ]
            project = data.google_project.hub_project_number.number
          }
          to = {
            services = local.case1_restricted_services
            methods  = ["\"*\""]
            project  = data.google_project.spoke2_project_number.number
          }
        },
      ]
    }
  }
}

# perimeter

locals {
  vpc_sc_config_case1_create = templatefile("../../templates/vpc-sc/create.sh", {
    ORGANIZATION_ID = var.organization_id
    POLICY_TITLE    = "${local.prefix}-policy"
    ACCESS_LEVELS   = [local.case1_access_level]
    PERIMETERS      = local.case1_perimeters
  })
  vpc_sc_config_case1_delete = templatefile("../../templates/vpc-sc/delete.sh", {
    ORGANIZATION_ID = var.organization_id
    POLICY_TITLE    = "${local.prefix}-policy"
    ACCESS_LEVELS   = [local.case1_access_level]
    PERIMETERS      = local.case1_perimeters
  })
}

resource "local_file" "vpc_sc_config_case1_create" {
  content  = local.vpc_sc_config_case1_create
  filename = "output/vpc-sc/case1/create.sh"
}

resource "local_file" "vpc_sc_config_case1_delete" {
  content  = local.vpc_sc_config_case1_delete
  filename = "output/vpc-sc/case1/delete.sh"
}
/*
# case2 (nva blueprint)
#------------------------------------------------------------
# hub perimeter:
#   - egress: site1-sa > spoke1 (storage)
#   - egress: site2-sa > spoke2 (storage)
#   - egress: spoke1-sa > spoke1 (storage)
#   - egress: spoke2-sa > spoke2 (storage)
# spoke1 perimeter:
#   - ingress: hub-project/site1-sa > storage
#   - ingress: hub-project/spoke1-sa > storage
#   - ingress: access-level (public ip) > storage
# spoke2 perimeter:
#   - ingress: hub-project/site2-sa > storage
#   - ingress: hub-project/spoke2-sa > storage
#------------------------------------------------------------

# config

locals {
  case2_restricted_services = ["storage.googleapis.com", "bigquery.googleapis.com"]
  case2_accessible_services = ["storage.googleapis.com", "bigquery.googleapis.com"]
  case2_access_levels = {
    ip = {
      "${local.prefix}_case1_external_ip" = ["1.1.1.1/32", "2.2.2.2/32"]
    }
  }
  case2_perimeters = {
    ("${local.prefix}_case2_hub") = {
      type                = "regular"
      project_number      = data.google_project.hub_project_number.number
      restricted_services = join(",", local.case2_restricted_services)
      accessible_services = join(",", local.case2_accessible_services)
      ingress             = []
      egress = [
        {
          from = { identity = module.site1_sa.email }
          to   = { service = "storage.googleapis.com", method = "\"*\"", project = data.google_project.spoke1_project_number.number }
        },
        {
          from = { identity = module.site2_sa.email }
          to   = { service = "storage.googleapis.com", method = "\"*\"", project = data.google_project.spoke2_project_number.number }
        },
        {
          from = { identity = module.spoke1_sa.email }
          to   = { service = "storage.googleapis.com", method = "\"*\"", project = data.google_project.spoke1_project_number.number }
        },
        {
          from = { identity = module.spoke2_sa.email }
          to   = { service = "storage.googleapis.com", method = "\"*\"", project = data.google_project.spoke2_project_number.number }
        },
      ]
    }
    ("${local.prefix}_case2_spoke1") = {
      type                = "regular"
      project_number      = data.google_project.spoke1_project_number.number
      restricted_services = join(",", local.case2_restricted_services)
      accessible_services = join(",", local.case2_accessible_services)
      egress              = []
      ingress = [
        {
          from = { identity = module.site1_sa.email, project = data.google_project.hub_project_number.number }
          to   = { service = "storage.googleapis.com", method = "\"*\"", project = data.google_project.spoke1_project_number.number }
        },
        {
          from = { identity = module.spoke1_sa.email, project = data.google_project.hub_project_number.number }
          to   = { service = "storage.googleapis.com", method = "\"*\"", project = data.google_project.spoke1_project_number.number }
        },
      ]
    }
    ("${local.prefix}_case2_spoke2") = {
      type                = "regular"
      project_number      = data.google_project.spoke2_project_number.number
      restricted_services = join(",", local.case2_restricted_services)
      accessible_services = join(",", local.case2_accessible_services)
      egress              = []
      ingress = [
        {
          from = { identity = module.site2_sa.email, project = data.google_project.hub_project_number.number }
          to   = { service = "storage.googleapis.com", method = "\"*\"", project = data.google_project.spoke2_project_number.number }
        },
        {
          from = { identity = module.spoke2_sa.email, project = data.google_project.hub_project_number.number }
          to   = { service = "storage.googleapis.com", method = "\"*\"", project = data.google_project.spoke2_project_number.number }
        },
      ]
    }
  }
}

# perimeter

locals {
  vpc_sc_config_case2_create = templatefile("../../templates/vpc-sc/create.sh", {
    ORGANIZATION_ID = var.organization_id
    POLICY_TITLE    = "${local.prefix}-policy"
    ACCESS_LEVELS   = local.case2_access_levels
    PERIMETERS      = local.case2_perimeters
  })
  vpc_sc_config_case2_delete = templatefile("../../templates/vpc-sc/delete.sh", {
    ORGANIZATION_ID = var.organization_id
    POLICY_TITLE    = "${local.prefix}-policy"
    ACCESS_LEVELS   = local.case2_access_levels
    PERIMETERS      = local.case2_perimeters
  })
}

resource "local_file" "vpc_sc_config_case2_create" {
  content  = local.vpc_sc_config_case2_create
  filename = "output/vpc-sc/case2/create.sh"
}

resource "local_file" "vpc_sc_config_case2_delete" {
  content  = local.vpc_sc_config_case2_delete
  filename = "output/vpc-sc/case2/delete.sh"
}
*/
