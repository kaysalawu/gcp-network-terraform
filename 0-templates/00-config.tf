
# netblocks

data "google_netblock_ip_ranges" "dns_forwarders" { range_type = "dns-forwarders" }
data "google_netblock_ip_ranges" "private_googleapis" { range_type = "private-googleapis" }
data "google_netblock_ip_ranges" "restricted_googleapis" { range_type = "restricted-googleapis" }
data "google_netblock_ip_ranges" "health_checkers" { range_type = "health-checkers" }
data "google_netblock_ip_ranges" "iap_forwarders" { range_type = "iap-forwarders" }

# common
#=====================================================

locals {
  supernet                = "10.0.0.0/8"
  cloud_domain            = "gcp"
  psk                     = "Password123"
  tag_router              = "router"
  tag_gfe                 = "gfe"
  tag_dns                 = "dns"
  tag_ssh                 = "ssh"
  tag_http                = "http-server"
  tag_https               = "https-server"
  tag_hub_int_eu_nva_ilb4 = "eu-nva-ilb4"
  tag_hub_int_us_nva_ilb4 = "us-nva-ilb4"
  netblocks = {
    dns      = data.google_netblock_ip_ranges.dns_forwarders.cidr_blocks_ipv4
    gfe      = data.google_netblock_ip_ranges.health_checkers.cidr_blocks_ipv4
    iap      = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
    internal = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  uhc_config = {
    host         = "probe.${local.cloud_domain}"
    request_path = "healthz"
    response     = "pass"
  }
  uhc_pan_config = {
    host = "google-hc-host"
  }
  svc_web = {
    name = "http8080"
    port = 8080
  }
  svc_juice = {
    name = "http3000"
    port = 3000
  }
  svc_grpc = {
    name = "grpc"
    port = 50051
  }
}

resource "random_id" "random" {
  byte_length = 2
}

# on-premises
#=====================================================

locals {
  onprem_domain = "onprem"
}

# site1
#--------------------------------

locals {
  site1_prefix     = local.prefix == "" ? "site1-" : join("-", [local.prefix, "site1-"])
  site1_asn        = "65010"
  site1_region     = "europe-west2"
  site1_supernet   = "10.10.0.0/16"
  site1_domain     = "site1"
  site1_app1_dns   = "app1"
  site1_vertex_dns = "vertex"
  site1_subnets = {
    ("${local.site1_prefix}subnet1") = {
      region                = local.site1_region
      ip_cidr_range         = "10.10.1.0/24"
      secondary_ip_range    = null
      subnet_flow_logs      = false
      log_config            = null
      private_google_access = false
      purpose               = "PRIVATE"
      role                  = null
    }
  }
  site1_gw_addr         = cidrhost(local.site1_subnets["${local.site1_prefix}subnet1"].ip_cidr_range, 1)
  site1_router_addr     = cidrhost(local.site1_subnets["${local.site1_prefix}subnet1"].ip_cidr_range, 2)
  site1_ns_addr         = cidrhost(local.site1_subnets["${local.site1_prefix}subnet1"].ip_cidr_range, 5)
  site1_vm_addr         = cidrhost(local.site1_subnets["${local.site1_prefix}subnet1"].ip_cidr_range, 9)
  site1_vertex_addr     = cidrhost(local.site1_subnets["${local.site1_prefix}subnet1"].ip_cidr_range, 20)
  site1_ids_attack_addr = cidrhost(local.site1_subnets["${local.site1_prefix}subnet1"].ip_cidr_range, 30)
  site1_router_lo_addr  = "1.1.1.1"
}

# site2
#--------------------------------

locals {
  site2_prefix   = local.prefix == "" ? "site2-" : join("-", [local.prefix, "site2-"])
  site2_asn      = "65020"
  site2_region   = "us-west2"
  site2_supernet = "10.20.0.0/16"
  site2_domain   = "site2"
  site2_app1_dns = "app1"
  site2_subnets = {
    ("${local.site2_prefix}subnet1") = {
      region                = local.site2_region
      ip_cidr_range         = "10.20.1.0/24"
      secondary_ip_range    = null
      subnet_flow_logs      = false
      log_config            = null
      private_google_access = false
      purpose               = "PRIVATE"
      role                  = null
    }
  }
  site2_gw_addr        = cidrhost(local.site2_subnets["${local.site2_prefix}subnet1"].ip_cidr_range, 1)
  site2_router_addr    = cidrhost(local.site2_subnets["${local.site2_prefix}subnet1"].ip_cidr_range, 2)
  site2_ns_addr        = cidrhost(local.site2_subnets["${local.site2_prefix}subnet1"].ip_cidr_range, 5)
  site2_vm_addr        = cidrhost(local.site2_subnets["${local.site2_prefix}subnet1"].ip_cidr_range, 9)
  site2_vertex_addr    = cidrhost(local.site2_subnets["${local.site2_prefix}subnet1"].ip_cidr_range, 20)
  site2_is_attck_addr  = cidrhost(local.site2_subnets["${local.site2_prefix}subnet1"].ip_cidr_range, 30)
  site2_router_lo_addr = "2.2.2.2"
}

# hub
#=====================================================

locals {
  hub_prefix        = local.prefix == "" ? "hub-" : join("-", [local.prefix, "hub-"])
  hub_eu_region     = "europe-west2"
  hub_us_region     = "us-west2"
  hub_eu_router_asn = "65001"
  hub_us_router_asn = "65002"
  hub_eu_ncc_cr_asn = "65011"
  hub_us_ncc_cr_asn = "65022"
  hub_eu_vpn_cr_asn = "65100"
  hub_us_vpn_cr_asn = "65200"
  hub_domain        = "hub"
  hub_psc_domain    = "psc.${local.hub_domain}.${local.cloud_domain}"
  hub_td_domain     = "td.${local.hub_domain}.${local.cloud_domain}"
  hub_svc_8001      = { name = "http8001", port = 8001 }
  hub_svc_8002      = { name = "http8002", port = 8002 }
  hub_supernet      = "10.1.0.0/16"
  hub_int_supernet  = "10.2.0.0/16"
  hub_mgt_supernet  = "10.3.0.0/16"
  hub_subnets = {
    ("${local.hub_prefix}eu-subnet1") = {
      region                     = local.hub_eu_region
      ip_cidr_range              = "10.1.11.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    ("${local.hub_prefix}eu-subnet2") = {
      region        = local.hub_eu_region
      ip_cidr_range = "10.1.12.0/24"
      secondary_ip_range = {
        pods     = "10.1.100.0/23"
        services = "10.1.102.0/24"
      }
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    ("${local.hub_prefix}eu-subnet3") = {
      region                     = local.hub_eu_region
      ip_cidr_range              = "10.1.13.0/24"
      secondary_ip_range         = {}
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "REGIONAL_MANAGED_PROXY"
      role                       = "ACTIVE"
    }
    ("${local.hub_prefix}us-subnet1") = {
      region                     = local.hub_us_region
      ip_cidr_range              = "10.1.21.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    ("${local.hub_prefix}us-subnet2") = {
      region        = local.hub_us_region
      ip_cidr_range = "10.1.22.0/24"
      secondary_ip_range = {
        pods     = "10.1.200.0/23"
        services = "10.1.202.0/24"
      }
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    ("${local.hub_prefix}us-subnet3") = {
      region                     = local.hub_us_region
      ip_cidr_range              = "10.1.23.0/24"
      secondary_ip_range         = {}
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "REGIONAL_MANAGED_PROXY"
      role                       = "ACTIVE"
    }
    "${local.hub_prefix}eu-psc-producer-nat-subnet1" = {
      region                     = local.hub_eu_region
      ip_cidr_range              = "192.168.1.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = false
      private_ipv6_google_access = false
      purpose                    = "PRIVATE_SERVICE_CONNECT"
      role                       = null
    }
    "${local.hub_prefix}us-psc-producer-nat-subnet1" = {
      region                     = local.hub_us_region
      ip_cidr_range              = "192.168.2.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = false
      private_ipv6_google_access = false
      purpose                    = "PRIVATE_SERVICE_CONNECT"
      role                       = null
    }
  }
  hub_mgt_subnets = {
    "${local.hub_prefix}mgt-eu-subnet1" = {
      region                     = local.hub_eu_region
      ip_cidr_range              = "10.2.11.0/24"
      secondary_ip_range         = {}
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.hub_prefix}mgt-us-subnet1" = {
      region                     = local.hub_us_region
      ip_cidr_range              = "10.2.21.0/24"
      secondary_ip_range         = {}
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
  }
  hub_int_subnets = {
    "${local.hub_prefix}int-eu-subnet1" = {
      region                     = local.hub_eu_region
      ip_cidr_range              = "10.3.11.0/24"
      secondary_ip_range         = {}
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.hub_prefix}int-eu-subnet2" = {
      region                     = local.spoke1_eu_region
      ip_cidr_range              = "10.3.12.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.hub_prefix}int-eu-subnet3" = {
      region                     = local.spoke1_eu_region
      ip_cidr_range              = "10.3.13.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "REGIONAL_MANAGED_PROXY"
      role                       = "ACTIVE"
    }
    "${local.hub_prefix}int-us-subnet1" = {
      region                     = local.hub_us_region
      ip_cidr_range              = "10.3.21.0/24"
      secondary_ip_range         = {}
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.hub_prefix}int-us-subnet2" = {
      region                     = local.hub_us_region
      ip_cidr_range              = "10.3.22.0/24"
      secondary_ip_range         = {}
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.hub_prefix}int-us-subnet3" = {
      region                     = local.hub_us_region
      ip_cidr_range              = "10.3.23.0/24"
      secondary_ip_range         = {}
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "REGIONAL_MANAGED_PROXY"
      role                       = "ACTIVE"
    }
  }

  # external
  #--------------------------------

  # prefixes
  hub_eu_gke_master_cidr1     = "172.16.11.0/28"
  hub_eu_gke_master_cidr2     = "172.16.11.16/28"
  hub_eu_psa_range1           = "10.1.120.0/22"
  hub_eu_psa_range2           = "10.1.124.0/22"
  hub_eu_fusion_range         = "10.1.128.0/22"
  hub_eu_filestore_range1     = "10.1.132.0/29"
  hub_eu_filestore_range2     = "10.1.136.8/29"
  hub_eu_memorystore_range1   = "10.1.140.16/29"
  hub_eu_memorystore_range2   = "10.1.144.24/29"
  hub_eu_vpc_connector_range1 = "10.1.148.0/28"

  hub_eu_gw_addr              = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 1)
  hub_eu_router_addr          = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 10)
  hub_eu_ncc_cr_addr0         = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 20)
  hub_eu_ncc_cr_addr1         = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 30)
  hub_eu_ns_addr              = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 40)
  hub_eu_nva_vm_addr          = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 50)
  hub_eu_nva_ilb4_addr        = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 60)
  hub_eu_ilb4_addr            = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 70)
  hub_eu_ilb7_addr            = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 80)
  hub_eu_hybrid_hc_proxy_addr = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 90)
  hub_eu_ids_server_addr      = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 91)
  hub_eu_ids_attack_addr      = cidrhost(local.hub_subnets["${local.hub_prefix}eu-subnet1"].ip_cidr_range, 92)
  hub_eu_router_lo_addr       = "11.11.11.11"

  hub_eu_subnet1_addresses = {
    "${local.hub_prefix}eu-ncc-cr-addr0"         = { addr = local.hub_eu_ncc_cr_addr0 }
    "${local.hub_prefix}eu-ncc-cr-addr1"         = { addr = local.hub_eu_ncc_cr_addr1 }
    "${local.hub_prefix}eu-router-addr"          = { addr = local.hub_eu_router_addr }
    "${local.hub_prefix}eu-ns-addr"              = { addr = local.hub_eu_ns_addr }
    "${local.hub_prefix}eu-nva-vm-addr"          = { addr = local.hub_eu_nva_vm_addr }
    "${local.hub_prefix}eu-nva-ilb4-addr"        = { addr = local.hub_eu_nva_ilb4_addr }
    "${local.hub_prefix}eu-ilb4-addr"            = { addr = local.hub_eu_ilb4_addr }
    "${local.hub_prefix}eu-hybrid-hc-proxy-addr" = { addr = local.hub_eu_hybrid_hc_proxy_addr }
    "${local.hub_prefix}eu-ids-server-addr"      = { addr = local.hub_eu_ids_server_addr }
    "${local.hub_prefix}eu-ids-attack-addr"      = { addr = local.hub_eu_ids_attack_addr }
  }
  hub_us_subnet1_addresses = {
    "${local.hub_prefix}us-ncc-cr-addr0"         = { addr = local.hub_us_ncc_cr_addr0 }
    "${local.hub_prefix}us-ncc-cr-addr1"         = { addr = local.hub_us_ncc_cr_addr1 }
    "${local.hub_prefix}us-router-addr"          = { addr = local.hub_us_router_addr }
    "${local.hub_prefix}us-ns-addr"              = { addr = local.hub_us_ns_addr }
    "${local.hub_prefix}us-nva-vm-addr"          = { addr = local.hub_us_nva_vm_addr }
    "${local.hub_prefix}us-nva-ilb4-addr"        = { addr = local.hub_us_nva_ilb4_addr }
    "${local.hub_prefix}us-ilb4-addr"            = { addr = local.hub_us_ilb4_addr }
    "${local.hub_prefix}us-hybrid-hc-proxy-addr" = { addr = local.hub_us_hybrid_hc_proxy_addr }
    "${local.hub_prefix}us-ids-server-addr"      = { addr = local.hub_us_ids_server_addr }
    "${local.hub_prefix}us-ids-attack-addr"      = { addr = local.hub_us_ids_attack_addr }
  }

  hub_us_gke_master_cidr1     = "172.16.11.32/28"
  hub_us_gke_master_cidr2     = "172.16.11.48/28"
  hub_us_psa_range1           = "10.1.220.0/22"
  hub_us_psa_range2           = "10.1.224.0/22"
  hub_us_fusion_range         = "10.1.228.0/22"
  hub_us_filestore_range1     = "10.1.232.0/29"
  hub_us_filestore_range2     = "10.1.236.8/29"
  hub_us_memorystore_range1   = "10.1.240.16/29"
  hub_us_memorystore_range2   = "10.1.244.24/29"
  hub_us_vpc_connector_range1 = "10.1.248.0/28"

  hub_us_gw_addr              = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 1)
  hub_us_router_addr          = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 10)
  hub_us_ncc_cr_addr0         = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 20)
  hub_us_ncc_cr_addr1         = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 30)
  hub_us_ns_addr              = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 40)
  hub_us_nva_vm_addr          = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 50)
  hub_us_nva_ilb4_addr        = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 60)
  hub_us_ilb4_addr            = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 70)
  hub_us_ilb7_addr            = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 80)
  hub_us_hybrid_hc_proxy_addr = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 90)
  hub_us_ids_server_addr      = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 91)
  hub_us_ids_attack_addr      = cidrhost(local.hub_subnets["${local.hub_prefix}us-subnet1"].ip_cidr_range, 92)
  hub_us_router_lo_addr       = "22.22.22.22"

  # psc/api
  hub_psc_api_fr_range    = "10.1.0.0/24"                           # vip range
  hub_psc_api_all_fr_name = "${local.prefix}huball"                 # all-apis forwarding rule name
  hub_psc_api_sec_fr_name = "${local.prefix}hubsec"                 # vpc-sc forwarding rule name
  hub_psc_api_all_fr_addr = cidrhost(local.hub_psc_api_fr_range, 1) # all-apis forwarding rule vip
  hub_psc_api_sec_fr_addr = cidrhost(local.hub_psc_api_fr_range, 2) # vpc-sc forwarding rule vip

  # psc/api http(s) service controls
  hub_eu_psc_https_ctrl_run_dns = "${local.hub_eu_region}-run.googleapis.com"
  hub_us_psc_https_ctrl_run_dns = "${local.hub_us_region}-run.googleapis.com"

  # psc/ilb consumer
  hub_eu_psc4_consumer_spoke1_eu_svc_dns = "psc4.consumer.spoke1-eu-svc" # hub consumer endpoint dns for spoke1 producer service
  hub_us_psc4_consumer_spoke2_us_svc_dns = "psc4.consumer.spoke2-us-svc" # hub consumer endpoint dns for spoke2 producer service

  # psc/ilb producer
  hub_eu_psc4_producer_nat = "192.168.11.0/24"
  hub_us_psc4_producer_nat = "192.168.12.0/24"

  # sql
  hub_eu_sql_proxy_dns = "sql.eu"
  hub_us_sql_proxy_dns = "sql.us"

  # nva
  hub_eu_nva_ilb4_dns = "nva.eu"
  hub_us_nva_ilb4_dns = "nva.us"

  # ilb
  hub_eu_ilb4_dns = "ilb4.eu"
  hub_eu_ilb7_dns = "ilb7.eu"
  hub_us_ilb4_dns = "ilb4.us"
  hub_us_ilb7_dns = "ilb7.us"

  # td
  hub_td_range                 = "172.16.0.0/24"
  hub_td_envoy_cloud_addr      = cidrhost(local.hub_td_range, 2)
  hub_td_envoy_hybrid_addr     = cidrhost(local.hub_td_range, 3)
  hub_td_grpc_cloud_svc        = "grpc-cloud"
  hub_td_envoy_cloud_svc       = "envoy-cloud"
  hub_td_envoy_hybrid_svc      = "envoy-hybrid"
  hub_td_envoy_bridge_ilb4_dns = "ilb4.envoy-bridge" # geo-dns resolves to regional endpoint

  # internal
  #--------------------------------

  # prefixes
  hub_int_eu_gw_addr       = cidrhost(local.hub_int_subnets["${local.hub_prefix}int-eu-subnet1"].ip_cidr_range, 1)
  hub_int_eu_nva_vm_addr   = cidrhost(local.hub_int_subnets["${local.hub_prefix}int-eu-subnet1"].ip_cidr_range, 10)
  hub_int_eu_nva_ilb4_addr = cidrhost(local.hub_int_subnets["${local.hub_prefix}int-eu-subnet1"].ip_cidr_range, 20)
  hub_int_us_gw_addr       = cidrhost(local.hub_int_subnets["${local.hub_prefix}int-us-subnet1"].ip_cidr_range, 1)
  hub_int_us_nva_vm_addr   = cidrhost(local.hub_int_subnets["${local.hub_prefix}int-us-subnet1"].ip_cidr_range, 10)
  hub_int_us_nva_ilb4_addr = cidrhost(local.hub_int_subnets["${local.hub_prefix}int-us-subnet1"].ip_cidr_range, 20)

  # psc/api
  hub_int_psc_api_fr_range    = "10.2.0.0/24"                               # vip range
  hub_int_psc_api_all_fr_name = "${local.prefix}hubintall"                  # all-apis forwarding rule name
  hub_int_psc_api_sec_fr_name = "${local.prefix}hubintsec"                  # vpc-sc forwarding rule name
  hub_int_psc_api_all_fr_addr = cidrhost(local.hub_int_psc_api_fr_range, 1) # all-apis forwarding rule vip
  hub_int_psc_api_sec_fr_addr = cidrhost(local.hub_int_psc_api_fr_range, 2) # vpc-sc forwarding rule vip

  # management
  #--------------------------------

  # prefixes
  hub_mgt_eu_gw_addr       = cidrhost(local.hub_mgt_subnets["${local.hub_prefix}mgt-eu-subnet1"].ip_cidr_range, 1)
  hub_mgt_eu_nva_vm_addr   = cidrhost(local.hub_mgt_subnets["${local.hub_prefix}mgt-eu-subnet1"].ip_cidr_range, 10)
  hub_mgt_eu_nva_ilb4_addr = cidrhost(local.hub_mgt_subnets["${local.hub_prefix}mgt-eu-subnet1"].ip_cidr_range, 20)
  hub_mgt_eu_vm_addr       = cidrhost(local.hub_mgt_subnets["${local.hub_prefix}mgt-eu-subnet1"].ip_cidr_range, 30)
  hub_mgt_us_gw_addr       = cidrhost(local.hub_mgt_subnets["${local.hub_prefix}mgt-us-subnet1"].ip_cidr_range, 1)
  hub_mgt_us_nva_vm_addr   = cidrhost(local.hub_mgt_subnets["${local.hub_prefix}mgt-us-subnet1"].ip_cidr_range, 10)
  hub_mgt_us_nva_ilb4_addr = cidrhost(local.hub_mgt_subnets["${local.hub_prefix}mgt-us-subnet1"].ip_cidr_range, 20)
  hub_mgt_us_vm_addr       = cidrhost(local.hub_mgt_subnets["${local.hub_prefix}mgt-us-subnet1"].ip_cidr_range, 30)

  # psc/api
  hub_mgt_psc_api_fr_range    = "10.3.0.0/24"                               # vip range
  hub_mgt_psc_api_all_fr_name = "${local.prefix}hubmgtall"                  # all-apis forwarding rule name
  hub_mgt_psc_api_sec_fr_name = "${local.prefix}hubmgtsec"                  # vpc-sc forwarding rule name
  hub_mgt_psc_api_all_fr_addr = cidrhost(local.hub_mgt_psc_api_fr_range, 1) # all-apis forwarding rule vip
  hub_mgt_psc_api_sec_fr_addr = cidrhost(local.hub_mgt_psc_api_fr_range, 2) # vpc-sc forwarding rule vip

  # psc/ilb consumer
  hub_mgt_eu_psc4_consumer_spoke1_eu_svc_dns = "psc4.consumer.spoke1-eu-svc" # hub consumer endpoint dns for spoke1 producer service
  hub_mgt_us_psc4_consumer_spoke2_us_svc_dns = "psc4.consumer.spoke2-us-svc" # hub consumer endpoint dns for spoke2 producer service

  # psc/producer
  hub_mgt_eu_psc4_producer_nat = "192.168.31.0/24"
  hub_mgt_us_psc4_producer_nat = "192.168.32.0/24"

  # ilb
  hub_mgt_eu_app1_dns = "app1.eu.mgt"
  hub_mgt_us_app1_dns = "app1.us.mgt"

  # td
  hub_mgt_td_grpc_cloud_svc   = "grpc-cloud"   # url map host for grpc service
  hub_mgt_td_envoy_cloud_svc  = "envoy-cloud"  # url map host for envoy service
  hub_mgt_td_envoy_hybrid_svc = "envoy-hybrid" # url map host for hybrid-envoy onprem service
  hub_mgt_td_domain           = "td.mgt.${local.hub_domain}.${local.cloud_domain}"
}

# spoke1
#=====================================================

locals {
  spoke1_prefix           = local.prefix == "" ? "spoke1-" : join("-", [local.prefix, "spoke1-"])
  spoke1_bucket_name      = "${local.spoke1_prefix}${var.project_id_spoke1}-bucket"
  spoke1_eu_cloudsql_name = "${local.spoke1_prefix}eu-cloudsql${random_id.random.hex}"
  spoke1_us_cloudsql_name = "${local.spoke1_prefix}us-cloudsql${random_id.random.hex}"
  spoke1_cloudsql_users   = { admin = { "host" = "%", "password" = "Password123" } }
  spoke1_asn              = "65411"
  spoke1_eu_region        = "europe-west2"
  spoke1_us_region        = "us-west2"
  spoke1_supernet         = "10.11.0.0/16"
  spoke1_domain           = "spoke1"
  spoke1_psc_domain       = "psc.${local.spoke1_domain}.${local.cloud_domain}"
  spoke1_td_domain        = "td.${local.spoke1_domain}.${local.cloud_domain}"
  spoke1_subnets = {
    "${local.spoke1_prefix}eu-subnet1" = {
      region                     = local.spoke1_eu_region
      ip_cidr_range              = "10.11.11.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = true
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.spoke1_prefix}eu-subnet2" = {
      region        = local.spoke1_eu_region
      ip_cidr_range = "10.11.12.0/24"
      secondary_ip_range = {
        pods     = "10.11.100.0/23"
        services = "10.11.102.0/24"
      }
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.spoke1_prefix}eu-subnet3" = {
      region                     = local.spoke1_eu_region
      ip_cidr_range              = "10.11.13.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "REGIONAL_MANAGED_PROXY"
      role                       = "ACTIVE"
    }
    "${local.spoke1_prefix}us-subnet1" = {
      region                     = local.spoke1_us_region
      ip_cidr_range              = "10.11.21.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.spoke1_prefix}us-subnet2" = {
      region        = local.spoke1_us_region
      ip_cidr_range = "10.11.22.0/24"
      secondary_ip_range = {
        pods     = "10.11.200.0/23"
        services = "10.11.202.0/24"
      }
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.spoke1_prefix}us-subnet3" = {
      region                     = local.spoke1_us_region
      ip_cidr_range              = "10.11.23.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "REGIONAL_MANAGED_PROXY"
      role                       = "ACTIVE"
    }
    "${local.spoke1_prefix}eu-psc-producer-nat-subnet1" = {
      region                     = local.spoke1_eu_region
      ip_cidr_range              = "192.168.11.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = false
      private_ipv6_google_access = false
      purpose                    = "PRIVATE_SERVICE_CONNECT"
      role                       = null
    }
    "${local.spoke1_prefix}us-psc-producer-nat-subnet1" = {
      region                     = local.spoke1_us_region
      ip_cidr_range              = "192.168.12.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = false
      private_ipv6_google_access = false
      purpose                    = "PRIVATE_SERVICE_CONNECT"
      role                       = null
    }
  }
  spoke1_gke_master_cidr1        = "172.16.11.0/28"
  spoke1_gke_master_cidr2        = "172.16.11.16/28"
  spoke1_eu_psa_range1           = "10.11.120.0/22"
  spoke1_eu_psa_range2           = "10.11.124.0/22"
  spoke1_eu_fusion_range         = "10.11.128.0/22"
  spoke1_eu_filestore_range1     = "10.11.132.0/29"
  spoke1_eu_filestore_range2     = "10.11.136.8/29"
  spoke1_eu_memorystore_range1   = "10.11.140.16/29"
  spoke1_eu_memorystore_range2   = "10.11.144.24/29"
  spoke1_eu_vpc_connector_range1 = "10.11.148.0/28"

  spoke1_eu_vm_google_reverse_internal = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"].ip_cidr_range, 15)
  spoke1_eu_ilb4_addr                  = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"].ip_cidr_range, 30)
  spoke1_eu_ilb7_addr                  = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"].ip_cidr_range, 40)
  spoke1_eu_td_envoy_bridge_ilb4_addr  = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"].ip_cidr_range, 50)
  spoke1_eu_sql_proxy_addr             = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"].ip_cidr_range, 60)
  spoke1_eu_hybrid_hc_proxy_addr       = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"].ip_cidr_range, 70)

  spoke1_us_vm_google_reverse_internal = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}us-subnet1"].ip_cidr_range, 15)
  spoke1_us_ilb4_addr                  = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}us-subnet1"].ip_cidr_range, 30)
  spoke1_us_ilb7_addr                  = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}us-subnet1"].ip_cidr_range, 40)
  spoke1_us_td_envoy_bridge_ilb4_addr  = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}us-subnet1"].ip_cidr_range, 50)
  spoke1_us_sql_proxy_addr             = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}us-subnet1"].ip_cidr_range, 60)
  spoke1_us_hybrid_hc_proxy_addr       = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}us-subnet1"].ip_cidr_range, 70)

  # psc/api
  spoke1_psc_api_fr_range    = "10.11.0.0/24"                             # vip range
  spoke1_psc_api_all_fr_name = "${local.prefix}spoke1all"                 # all-apis forwarding rule name
  spoke1_psc_api_sec_fr_name = "${local.prefix}spoke1sec"                 # vpc-sc forwarding rule name
  spoke1_psc_api_all_fr_addr = cidrhost(local.spoke1_psc_api_fr_range, 1) # all-apis forwarding rule vip
  spoke1_psc_api_sec_fr_addr = cidrhost(local.spoke1_psc_api_fr_range, 2) # vpc-sc forwarding rule vip

  # psc/api http(s) service controls
  spoke1_eu_psc_https_ctrl_run_dns = "${local.spoke1_eu_region}-run.googleapis.com"
  spoke1_us_psc_https_ctrl_run_dns = "${local.spoke1_us_region}-run.googleapis.com"

  # psc/ilb consumer
  spoke1_us_psc4_consumer_spoke2_us_svc_dns = "psc4.consumer.spoke2-us-svc" # spoke1 consumer endpoint dns for spoke2 producer service

  # psc/ilb producer
  spoke1_eu_psc4_producer_nat = "192.168.101.0/24"
  spoke1_us_psc4_producer_nat = "192.168.102.0/24"

  # sql
  spoke1_eu_sql_proxy_dns = "sql.eu"
  spoke1_us_sql_proxy_dns = "sql.us"

  # ilb
  spoke1_eu_test_vm  = "test.eu"
  spoke1_eu_ilb4_dns = "ilb4.eu"
  spoke1_eu_ilb7_dns = "ilb7.eu"
  spoke1_us_ilb4_dns = "ilb4.us"
  spoke1_us_ilb7_dns = "ilb7.us"

  # td
  spoke1_td_range                 = "172.16.11.0/24"
  spoke1_td_envoy_cloud_addr      = cidrhost(local.spoke1_td_range, 2)
  spoke1_td_envoy_hybrid_addr     = cidrhost(local.spoke1_td_range, 3)
  spoke1_td_grpc_cloud_svc        = "grpc-cloud"
  spoke1_td_envoy_cloud_svc       = "envoy-cloud"
  spoke1_td_envoy_hybrid_svc      = "envoy-hybrid"
  spoke1_td_envoy_bridge_ilb4_dns = "ilb4.envoy-bridge" # geo-dns resolves to regional endpoint
}

# spoke2
#=====================================================

locals {
  spoke2_prefix           = local.prefix == "" ? "spoke2-" : join("-", [local.prefix, "spoke2-"])
  spoke2_bucket_name      = "${local.spoke2_prefix}${var.project_id_spoke2}-bucket"
  spoke2_eu_cloudsql_name = "${local.spoke2_prefix}eu-cloudsql${random_id.random.hex}"
  spoke2_us_cloudsql_name = "${local.spoke2_prefix}us-cloudsql${random_id.random.hex}"
  spoke2_cloudsql_users   = { admin = { "host" = "%", "password" = "Password123" } }
  spoke2_asn              = "65422"
  spoke2_eu_region        = "europe-west2"
  spoke2_us_region        = "us-west2"
  spoke2_supernet         = "10.22.0.0/16"
  spoke2_domain           = "spoke2"
  spoke2_psc_domain       = "psc.${local.spoke2_domain}.${local.cloud_domain}"
  spoke2_td_domain        = "td.${local.spoke2_domain}.${local.cloud_domain}"
  spoke2_subnets = {
    "${local.spoke2_prefix}eu-subnet1" = {
      region                     = local.spoke2_eu_region
      ip_cidr_range              = "10.22.11.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.spoke2_prefix}eu-subnet2" = {
      region        = local.spoke2_eu_region
      ip_cidr_range = "10.22.12.0/24"
      secondary_ip_range = {
        pods     = "10.22.100.0/23"
        services = "10.22.102.0/24"
      }
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.spoke2_prefix}eu-subnet3" = {
      region                     = local.spoke2_eu_region
      ip_cidr_range              = "10.22.13.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = false
      private_ipv6_google_access = false
      purpose                    = "REGIONAL_MANAGED_PROXY"
      role                       = "ACTIVE"
    }
    "${local.spoke2_prefix}us-subnet1" = {
      region                     = local.spoke2_us_region
      ip_cidr_range              = "10.22.21.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.spoke2_prefix}us-subnet2" = {
      region        = local.spoke2_us_region
      ip_cidr_range = "10.22.22.0/24"
      secondary_ip_range = {
        pods     = "10.22.200.0/23"
        services = "10.22.202.0/24"
      }
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    "${local.spoke2_prefix}us-subnet3" = {
      region                     = local.spoke2_us_region
      ip_cidr_range              = "10.22.23.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      private_google_access      = false
      private_ipv6_google_access = false
      purpose                    = "REGIONAL_MANAGED_PROXY"
      role                       = "ACTIVE"
    }
    "${local.spoke2_prefix}eu-psc-producer-nat-subnet1" = {
      region                     = local.spoke2_eu_region
      ip_cidr_range              = "192.168.21.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = false
      private_ipv6_google_access = false
      purpose                    = "PRIVATE_SERVICE_CONNECT"
      role                       = null
    }
    "${local.spoke2_prefix}us-psc-producer-nat-subnet1" = {
      region                     = local.spoke2_us_region
      ip_cidr_range              = "192.168.22.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = false
      private_ipv6_google_access = false
      purpose                    = "PRIVATE_SERVICE_CONNECT"
      role                       = null
    }
  }
  spoke2_gke_master_cidr1        = "172.16.22.0/28"
  spoke2_gke_master_cidr2        = "172.16.22.16/28"
  spoke2_us_psa_range1           = "10.22.120.0/22"
  spoke2_us_psa_range2           = "10.22.124.0/22"
  spoke2_us_fusion_range         = "10.22.128.0/22"
  spoke2_us_filestore_range1     = "10.22.132.0/29"
  spoke2_us_filestore_range2     = "10.22.136.8/29"
  spoke2_us_memorystore_range1   = "10.22.140.16/29"
  spoke2_us_memorystore_range2   = "10.22.144.24/29"
  spoke2_us_vpc_connector_range1 = "10.22.148.0/28"

  spoke2_eu_vm_google_reverse_internal = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}eu-subnet1"].ip_cidr_range, 15)
  spoke2_eu_ilb4_addr                  = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}eu-subnet1"].ip_cidr_range, 30)
  spoke2_eu_ilb7_addr                  = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}eu-subnet1"].ip_cidr_range, 40)
  spoke2_eu_td_envoy_bridge_ilb4_addr  = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}eu-subnet1"].ip_cidr_range, 50)
  spoke2_eu_sql_proxy_addr             = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}eu-subnet1"].ip_cidr_range, 60)
  spoke2_eu_hybrid_hc_proxy_addr       = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}eu-subnet1"].ip_cidr_range, 70)

  spoke2_us_vm_google_reverse_internal = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}us-subnet1"].ip_cidr_range, 15)
  spoke2_us_ilb4_addr                  = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}us-subnet1"].ip_cidr_range, 30)
  spoke2_us_ilb7_addr                  = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}us-subnet1"].ip_cidr_range, 40)
  spoke2_us_td_envoy_bridge_ilb4_addr  = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}us-subnet1"].ip_cidr_range, 50)
  spoke2_us_sql_proxy_addr             = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}us-subnet1"].ip_cidr_range, 60)
  spoke2_us_hybrid_hc_proxy_addr       = cidrhost(local.spoke2_subnets["${local.spoke2_prefix}us-subnet1"].ip_cidr_range, 70)

  # psc/api
  spoke2_psc_api_fr_range    = "10.22.0.0/24"                             # vip range
  spoke2_psc_api_all_fr_name = "${local.prefix}spoke2all"                 # all-apis forwarding rule name
  spoke2_psc_api_sec_fr_name = "${local.prefix}spoke2sec"                 # vpc-sc forwarding rule name
  spoke2_psc_api_all_fr_addr = cidrhost(local.spoke2_psc_api_fr_range, 1) # all-apis forwarding rule vip
  spoke2_psc_api_sec_fr_addr = cidrhost(local.spoke2_psc_api_fr_range, 2) # vpc-sc forwarding rule vip

  # psc/api http(s) service controls
  spoke2_eu_psc_https_ctrl_run_dns = "${local.spoke2_eu_region}-run.googleapis.com"
  spoke2_us_psc_https_ctrl_run_dns = "${local.spoke2_us_region}-run.googleapis.com"

  # psc/ilb consumer
  spoke2_eu_psc4_consumer_spoke1_eu_svc_dns = "psc4.consumer.spoke1-eu-svc" # spoke2 consumer endpoint dns for spoke1 producer service

  # psc/ilb producer
  spoke2_eu_psc4_producer_nat = "192.168.201.0/24"
  spoke2_us_psc4_producer_nat = "192.168.202.0/24"

  # sql
  spoke2_eu_sql_proxy_dns = "sql.eu"
  spoke2_us_sql_proxy_dns = "sql.us"

  # ilb
  spoke2_eu_test_vm  = "test.eu"
  spoke2_eu_ilb4_dns = "ilb4.eu"
  spoke2_eu_ilb7_dns = "ilb7.eu"
  spoke2_us_ilb4_dns = "ilb4.us"
  spoke2_us_ilb7_dns = "ilb7.us"

  # td
  spoke2_td_range                 = "172.16.22.0/24"
  spoke2_td_envoy_cloud_addr      = cidrhost(local.spoke2_td_range, 2)
  spoke2_td_envoy_hybrid_addr     = cidrhost(local.spoke2_td_range, 3)
  spoke2_td_grpc_cloud_svc        = "grpc-cloud"
  spoke2_td_envoy_cloud_svc       = "envoy-cloud"
  spoke2_td_envoy_hybrid_svc      = "envoy-hybrid"
  spoke2_td_envoy_bridge_ilb4_dns = "ilb4.envoy-bridge" # geo-dns resolves to regional endpoint
}
