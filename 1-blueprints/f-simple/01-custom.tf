
# common
#---------------------------------

locals {
  prefix = "f"
  targets_app = [
    "${local.site1_app1_dns}.${local.site1_domain}.${local.onprem_domain}:${local.svc_web.port}/",
    "${local.site2_app1_dns}.${local.site2_domain}.${local.onprem_domain}:${local.svc_web.port}/",
    "${local.hub_eu_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}:${local.svc_web.port}/",
    "${local.hub_us_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}:${local.svc_web.port}/",
    "${local.hub_eu_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}/",
    "${local.hub_us_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}/",
  ]
  targets_ping = [
    "${local.site1_app1_dns}.${local.site1_domain}.${local.onprem_domain}",
    "${local.site2_app1_dns}.${local.site2_domain}.${local.onprem_domain}",
    "${local.hub_eu_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}",
    "${local.hub_us_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}",
    "${local.hub_eu_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}",
    "${local.hub_us_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}",
  ]
  targets_pga = [
    "www.googleapis.com/generate_204",
    "storage.googleapis.com/generate_204",
    "${local.hub_eu_psc_https_ctrl_run_dns}/generate_204",        # custom psc ilb7 access to regional cloud run service
    "${local.hub_us_psc_https_ctrl_run_dns}/generate_204",        # custom psc ilb7 access to regional cloud run service
    "${local.hub_eu_run_flasky_host}/",                           # cloud run in hub project
    "${local.hub_psc_api_fr_name}.p.googleapis.com/generate_204", # psc/api endpoint in hub project
  ]
}
