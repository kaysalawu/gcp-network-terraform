
# common
#---------------------------------

locals {
  prefix = "d"
  targets_app = [
    "${local.site1_app1_dns}.${local.site1_domain}.${local.onprem_domain}:${local.svc_web.port}/",
    "${local.site2_app1_dns}.${local.site2_domain}.${local.onprem_domain}:${local.svc_web.port}/",
    "${local.hub_eu_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}:${local.svc_web.port}/",
    "${local.hub_us_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}:${local.svc_web.port}/",
    "${local.hub_eu_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}/",
    "${local.hub_us_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}/",
    "${local.spoke1_eu_ilb4_dns}.${local.spoke1_domain}.${local.cloud_domain}:${local.svc_web.port}/",
    "${local.spoke2_us_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}:${local.svc_web.port}/",
    "${local.spoke1_eu_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}/",
    "${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}/",
    "${local.hub_eu_nva_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}:${local.hub_svc_8001.port}/",
    "${local.hub_eu_nva_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}:${local.hub_svc_8002.port}/",
    "${local.hub_us_nva_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}:${local.hub_svc_8001.port}/",
    "${local.hub_us_nva_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}:${local.hub_svc_8002.port}/",
    "${local.hub_mgt_eu_app1_dns}.${local.hub_domain}.${local.cloud_domain}:${local.svc_web.port}/",
    "${local.hub_mgt_us_app1_dns}.${local.hub_domain}.${local.cloud_domain}:${local.svc_web.port}/",
  ]
  targets_ping = [
    "${local.site1_app1_dns}.${local.site1_domain}.${local.onprem_domain}",
    "${local.site2_app1_dns}.${local.site2_domain}.${local.onprem_domain}",
    "${local.hub_eu_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}",
    "${local.hub_us_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}",
    "${local.hub_eu_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}",
    "${local.hub_us_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}",
    "${local.spoke1_eu_ilb4_dns}.${local.spoke1_domain}.${local.cloud_domain}",
    "${local.spoke2_us_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}",
    "${local.spoke1_eu_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}",
    "${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}",
    "${local.hub_eu_nva_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}",
    "${local.hub_us_nva_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}",
    "${local.hub_mgt_eu_app1_dns}.${local.hub_domain}.${local.cloud_domain}",
    "${local.hub_mgt_us_app1_dns}.${local.hub_domain}.${local.cloud_domain}",
  ]
  targets_pga = [
    "www.googleapis.com/generate_204",
    "storage.googleapis.com/generate_204",
    "${local.spoke1_eu_psc_https_ctrl_run_dns}/generate_204",        # custom psc ilb7 access to regional service
    "${local.spoke2_us_psc_https_ctrl_run_dns}/generate_204",        # custom psc ilb7 access to regional service
    "${local.hub_eu_psc_https_ctrl_run_dns}/generate_204",           # custom psc ilb7 access to regional service
    "${local.hub_us_psc_https_ctrl_run_dns}/generate_204",           # custom psc ilb7 access to regional service
    "${local.hub_eu_run_flasky_host}/",                              # cloud run in hub project
    "${local.spoke1_eu_run_flasky_host}/",                           # cloud run in spoke1 project
    "${local.spoke2_us_run_flasky_host}/",                           # cloud run in spoke1 project
    "${local.hub_psc_api_fr_name}.p.googleapis.com/generate_204",    # psc/api endpoint in hub project
    "${local.spoke1_psc_api_fr_name}.p.googleapis.com/generate_204", # psc/api endpoint in spoke1 project
    "${local.spoke2_psc_api_fr_name}.p.googleapis.com/generate_204"  # psc/api endpoint in spoke2 project
  ]
}

# hub
#---------------------------------

# nva

locals {
  hub_nva_eu_startup = templatefile("scripts/startup/nva.sh", {
    GOOGLE_RANGES        = concat(local.netblocks.gfe, local.netblocks.dns)
    ENS5_LINKED_NETWORKS = [local.spoke1_supernet]
    ENS6_LINKED_NETWORKS = [local.hub_mgt_subnets["${local.hub_prefix}mgt-us-subnet1"].ip_cidr_range] # eu-subnet1 is directly attached and not included
    IPTABLES_RULES = [
      "iptables -A PREROUTING -t nat -p tcp --dport ${local.hub_svc_8001.port} -j DNAT --to-destination ${local.spoke1_eu_ilb4_addr}:${local.svc_web.port}",
      "iptables -A PREROUTING -t nat -p tcp --dport ${local.hub_svc_8002.port} -j DNAT --to-destination ${local.spoke1_eu_ilb4_addr}:${local.svc_web.port}",
      "iptables -A POSTROUTING -t nat -p tcp --dport ${local.hub_svc_8001.port} -j SNAT --to-source ${local.hub_int_eu_nva_vm_addr}",
      "iptables -A POSTROUTING -t nat -p tcp --dport ${local.hub_svc_8002.port} -j SNAT --to-source ${local.hub_int_eu_nva_vm_addr}",
      "iptables -A POSTROUTING -t nat -d ${local.hub_eu_ns_addr} -j SNAT --to-source ${local.hub_eu_nva_vm_addr}",
      "iptables -P INPUT ACCEPT",
      "iptables -P OUTPUT ACCEPT",
      "iptables -P FORWARD ACCEPT",
      "iptables -F",
    ]
    HEALTH_CHECK = {
      port     = local.svc_web.port
      path     = local.uhc_config.request_path
      response = local.uhc_config.response
    }
    TARGETS_APP = local.targets_app
    TARGETS_PSC = local.targets_psc
    TARGETS_PGA = local.targets_pga
  })
  hub_nva_us_startup = templatefile("scripts/startup/nva.sh", {
    GOOGLE_RANGES        = concat(local.netblocks.gfe, local.netblocks.dns)
    ENS5_LINKED_NETWORKS = [local.spoke2_supernet]
    ENS6_LINKED_NETWORKS = [local.hub_mgt_subnets["${local.hub_prefix}mgt-eu-subnet1"].ip_cidr_range] # us-subnet1 is directly attached and not included
    IPTABLES_RULES = [
      "iptables -A PREROUTING -t nat -p tcp --dport ${local.hub_svc_8001.port} -j DNAT --to-destination ${local.spoke2_us_ilb4_addr}:${local.svc_web.port}",
      "iptables -A PREROUTING -t nat -p tcp --dport ${local.hub_svc_8002.port} -j DNAT --to-destination ${local.spoke2_us_ilb4_addr}:${local.svc_web.port}",
      "iptables -A POSTROUTING -t nat -p tcp --dport ${local.hub_svc_8001.port} -j SNAT --to-source ${local.hub_int_us_nva_vm_addr}",
      "iptables -A POSTROUTING -t nat -p tcp --dport ${local.hub_svc_8002.port} -j SNAT --to-source ${local.hub_int_us_nva_vm_addr}",
      "iptables -A POSTROUTING -t nat -d ${local.hub_us_ns_addr} -j SNAT --to-source ${local.hub_us_nva_vm_addr}",
      "iptables -P INPUT ACCEPT",
      "iptables -P OUTPUT ACCEPT",
      "iptables -P FORWARD ACCEPT",
      "iptables -F",
    ]
    HEALTH_CHECK = {
      port     = local.svc_web.port
      path     = local.uhc_config.request_path
      response = local.uhc_config.response
    }
    TARGETS_APP = local.targets_app
    TARGETS_PSC = local.targets_psc
    TARGETS_PGA = local.targets_pga
  })
}

# psc/api

locals {
  hub_mgt_psc_api_fr_name = (
    local.hub_mgt_psc_api_secure ?
    local.hub_mgt_psc_api_sec_fr_name :
    local.hub_mgt_psc_api_all_fr_name
  )
  hub_mgt_psc_api_fr_addr = (
    local.hub_mgt_psc_api_secure ?
    local.hub_mgt_psc_api_sec_fr_addr :
    local.hub_mgt_psc_api_all_fr_addr
  )
  hub_mgt_psc_api_fr_target = (
    local.hub_mgt_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  hub_int_psc_api_fr_name = (
    local.hub_int_psc_api_secure ?
    local.hub_int_psc_api_sec_fr_name :
    local.hub_int_psc_api_all_fr_name
  )
  hub_int_psc_api_fr_addr = (
    local.hub_int_psc_api_secure ?
    local.hub_int_psc_api_sec_fr_addr :
    local.hub_int_psc_api_all_fr_addr
  )
  hub_int_psc_api_fr_target = (
    local.hub_int_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  hub_mgt_psc_api_secure = false
  hub_int_psc_api_secure = false
}
