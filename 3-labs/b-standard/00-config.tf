
# netblocks

data "google_netblock_ip_ranges" "dns_forwarders" { range_type = "dns-forwarders" }
data "google_netblock_ip_ranges" "private_googleapis" { range_type = "private-googleapis" }
data "google_netblock_ip_ranges" "restricted_googleapis" { range_type = "restricted-googleapis" }
data "google_netblock_ip_ranges" "health_checkers" { range_type = "health-checkers" }
data "google_netblock_ip_ranges" "iap_forwarders" { range_type = "iap-forwarders" }

# common
#=====================================================

locals {
  supernet               = "10.0.0.0/8"
  supernet6              = "fd20::/20"
  cloud_domain           = "g.corp"
  onprem_domain          = "corp"
  psk                    = "Password123"
  tag_router             = "router"
  tag_gfe                = "gfe"
  tag_dns                = "dns"
  tag_ssh                = "ssh"
  tag_http               = "http-server"
  tag_https              = "https-server"
  tag_hub_int_eu_nva_ilb = "eu-nva-ilb"
  tag_hub_int_us_nva_ilb = "us-nva-ilb"
  region1                = "europe-west2"
  region2                = "us-west2"

  private_prefixes = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "100.64.0.0/10",
  ]
  private_prefixes_ipv6 = [
    "fd20::/20",
  ]

  netblocks = {
    dns = data.google_netblock_ip_ranges.dns_forwarders.cidr_blocks_ipv4
    gfe = concat(
      data.google_netblock_ip_ranges.health_checkers.cidr_blocks_ipv4,
      # global internet negs
      # dig TXT _cloud-eoips.googleusercontent.com | grep -Eo 'ip4:[^ ]+' | cut -d':' -f2
      ["34.96.0.0/20", "34.127.192.0/18", ]
    )
    iap      = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
    internal = local.private_prefixes
  }

  netblocks_ipv6 = {
    gfe      = ["2600:2d00:1:b029::/64", "2600:2d00:1:1::/64", "2600:1901:8001::/48", ]
    internal = local.private_prefixes_ipv6
  }

  bgp_range1  = "169.254.101.0/30"
  bgp_range2  = "169.254.102.0/30"
  bgp_range3  = "169.254.103.0/30"
  bgp_range4  = "169.254.104.0/30"
  bgp_range5  = "169.254.105.0/30"
  bgp_range6  = "169.254.106.0/30"
  bgp_range7  = "169.254.107.0/30"
  bgp_range8  = "169.254.108.0/30"
  bgp_range9  = "169.254.109.0/30"
  bgp_range10 = "169.254.110.0/30"

  bgp_range1_ipv6 = "2600:2d00:0:2::/64"
  bgp_range2_ipv6 = "2600:2d00:0:3::/64"

  gre_range1  = "172.16.1.0/24"
  gre_range2  = "172.16.2.0/24"
  gre_range3  = "172.16.3.0/24"
  gre_range4  = "172.16.4.0/24"
  gre_range5  = "172.16.5.0/24"
  gre_range6  = "172.16.6.0/24"
  gre_range7  = "172.16.7.0/24"
  gre_range8  = "172.16.8.0/24"
  gre_range9  = "172.16.9.0/24"
  gre_range10 = "172.16.10.0/24"

  image_vyos  = "https://www.googleapis.com/compute/v1/projects/sentrium-public/global/images/vyos-1-3-0"
  image_panos = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/vmseries-bundle1-810"

  uhc_config     = { host = "probe.${local.cloud_domain}", request_path = "healthz", response = "OK" }
  uhc_pan_config = { host = "google-hc-host" }
  svc_web        = { name = "http", port = 80 }
  svc_juice      = { name = "http3000", port = 3000 }
  svc_grpc       = { name = "grpc", port = 50051 }

  flow_logs_config = { flow_sampling = 0.5, aggregation_interval = "INTERVAL_10_MIN" }
}

resource "random_id" "random" {
  byte_length = 2
}

# on-premises
#=====================================================

# site1
#--------------------------------

locals {
  site1_prefix   = var.prefix == "" ? "site1-" : join("-", [var.prefix, "site1-"])
  site1_asn      = "65010"
  site1_region   = local.region1
  site1_supernet = "10.10.0.0/16"
  site1_domain   = "site1"
  site1_dns_zone = "${local.site1_domain}.${local.onprem_domain}"

  site1_subnets_list = [for k, v in local.site1_subnets : merge({ name = k }, v)]
  site1_subnets = {
    main = { region = local.site1_region, ip_cidr_range = "10.10.1.0/24", ipv6 = {} }
  }
  site1_gw_addr        = cidrhost(local.site1_subnets["main"].ip_cidr_range, 1)
  site1_router_addr    = cidrhost(local.site1_subnets["main"].ip_cidr_range, 2)
  site1_ns_addr        = cidrhost(local.site1_subnets["main"].ip_cidr_range, 5)
  site1_vm_addr        = cidrhost(local.site1_subnets["main"].ip_cidr_range, 9)
  site1_router_lo_addr = "1.1.1.1"

  site1_vm_dns_prefix = "vm"
  site1_vm_fqdn       = "${local.site1_vm_dns_prefix}.${local.site1_dns_zone}"
}

# site2
#--------------------------------

locals {
  site2_prefix   = var.prefix == "" ? "site2-" : join("-", [var.prefix, "site2-"])
  site2_asn      = "65020"
  site2_region   = local.region2
  site2_supernet = "10.20.0.0/16"
  site2_domain   = "site2"
  site2_vm_dns   = "vm"
  site2_dns_zone = "${local.site2_domain}.${local.onprem_domain}"

  site2_subnets_list = [for k, v in local.site2_subnets : merge({ name = k }, v)]
  site2_subnets = {
    main = { region = local.site2_region, ip_cidr_range = "10.20.1.0/24", ipv6 = {} }
  }
  site2_gw_addr        = cidrhost(local.site2_subnets["main"].ip_cidr_range, 1)
  site2_router_addr    = cidrhost(local.site2_subnets["main"].ip_cidr_range, 2)
  site2_ns_addr        = cidrhost(local.site2_subnets["main"].ip_cidr_range, 5)
  site2_vm_addr        = cidrhost(local.site2_subnets["main"].ip_cidr_range, 9)
  site2_router_lo_addr = "2.2.2.2"

  site2_vm_dns_prefix = "vm"
  site2_vm_fqdn       = "${local.site2_vm_dns_prefix}.${local.site2_dns_zone}"
}

# hub
#=====================================================

locals {
  hub_prefix        = var.prefix == "" ? "hub-" : join("-", [var.prefix, "hub-"])
  hub_eu_region     = local.region1
  hub_us_region     = local.region2
  hub_eu_router_asn = "65001"
  hub_us_router_asn = "65002"
  hub_eu_ncc_cr_asn = "65011"
  hub_us_ncc_cr_asn = "65022"
  hub_eu_vpn_cr_asn = "65100"
  hub_us_vpn_cr_asn = "65200"
  hub_domain        = "hub"
  hub_dns_zone      = "${local.hub_domain}.${local.cloud_domain}"
  # hub_psc_domain    = "psc.${local.hub_domain}.${local.cloud_domain}"
  hub_svc_8001     = { name = "http8001", port = 8001 }
  hub_svc_8002     = { name = "http8002", port = 8002 }
  hub_supernet     = "10.1.0.0/16"
  hub_int_supernet = "10.2.0.0/16"
  hub_mgt_supernet = "10.3.0.0/16"

  hub_subnets = merge(
    local.hub_subnets_eu, local.hub_subnets_us,
  )
  hub_subnets_list             = [for k, v in local.hub_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == null]
  hub_subnets_private_nat_list = [for k, v in local.hub_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == "PRIVATE_NAT"]
  hub_subnets_proxy_only_list  = [for k, v in local.hub_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == "REGIONAL_MANAGED_PROXY"]
  hub_subnets_psc_list         = [for k, v in local.hub_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == "PRIVATE_SERVICE_CONNECT"]

  hub_subnets_eu = {
    eu-main         = { region = local.hub_eu_region, ip_cidr_range = "10.1.11.0/24", ipv6 = {}, enable_private_access = true, flow_logs_config = local.flow_logs_config, }
    eu-gke          = { region = local.hub_eu_region, ip_cidr_range = "10.1.12.0/24", ipv6 = {}, enable_private_access = true, secondary_ip_ranges = { pods = "10.1.100.0/23", services = "10.1.102.0/24" } }
    eu-reg-proxy    = { region = local.hub_eu_region, ip_cidr_range = "10.1.13.0/24", ipv6 = {}, enable_private_access = false, purpose = "REGIONAL_MANAGED_PROXY", role = "ACTIVE" }
    eu-psc-ilb-nat  = { region = local.hub_eu_region, ip_cidr_range = "10.1.14.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-ilb-nat6 = { region = local.hub_eu_region, ip_cidr_range = "10.1.15.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-nlb-nat  = { region = local.hub_eu_region, ip_cidr_range = "10.1.16.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-nlb-nat6 = { region = local.hub_eu_region, ip_cidr_range = "10.1.17.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-ilb-nat  = { region = local.hub_eu_region, ip_cidr_range = "10.1.18.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-ilb-nat6 = { region = local.hub_eu_region, ip_cidr_range = "10.1.19.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
  }
  hub_subnets_us = {
    us-main         = { region = local.hub_us_region, ip_cidr_range = "10.1.21.0/24", ipv6 = {}, enable_private_access = true }
    us-gke          = { region = local.hub_us_region, ip_cidr_range = "10.1.22.0/24", ipv6 = {}, enable_private_access = true, secondary_ip_ranges = { pods = "10.1.200.0/23", services = "10.1.202.0/24" } }
    us-reg-proxy    = { region = local.hub_us_region, ip_cidr_range = "10.1.23.0/24", ipv6 = {}, enable_private_access = false, purpose = "REGIONAL_MANAGED_PROXY", role = "ACTIVE" }
    us-psc-ilb-nat  = { region = local.hub_us_region, ip_cidr_range = "10.1.24.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-ilb-nat6 = { region = local.hub_us_region, ip_cidr_range = "10.1.25.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-nlb-nat  = { region = local.hub_us_region, ip_cidr_range = "10.1.26.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-nlb-nat6 = { region = local.hub_us_region, ip_cidr_range = "10.1.27.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-ilb-nat  = { region = local.hub_us_region, ip_cidr_range = "10.1.28.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-ilb-nat6 = { region = local.hub_us_region, ip_cidr_range = "10.1.29.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
  }

  # external
  #--------------------------------

  # prefixes
  hub_eu_gke_master_cidr1 = "172.16.11.0/28"
  hub_eu_gke_master_cidr2 = "172.16.11.16/28"
  hub_eu_psa_range1       = "10.1.120.0/22"
  hub_eu_psa_range2       = "10.1.124.0/22"

  hub_eu_main_default_gw      = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 1)
  hub_eu_vm_addr              = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 9)
  hub_eu_router_addr          = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 10)
  hub_eu_ncc_cr_addr0         = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 20)
  hub_eu_ncc_cr_addr1         = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 30)
  hub_eu_ns_addr              = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 40)
  hub_eu_nva_vm_addr          = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 50)
  hub_eu_nva_ilb_addr         = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 60)
  hub_eu_ilb_addr             = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 70)
  hub_eu_alb_addr             = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 80)
  hub_eu_hybrid_hc_proxy_addr = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 90)
  hub_eu_ids_server_addr      = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 91)
  hub_eu_ids_attack_addr      = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 92)
  hub_eu_router_lo_addr       = "11.11.11.11"

  hub_eu_main_addresses = {
    "${local.hub_prefix}eu-ncc-cr-addr0" = { ipv4 = local.hub_eu_ncc_cr_addr0 }
    "${local.hub_prefix}eu-ncc-cr-addr1" = { ipv4 = local.hub_eu_ncc_cr_addr1 }
    "${local.hub_prefix}eu-router-addr"  = { ipv4 = local.hub_eu_router_addr }
    "${local.hub_prefix}eu-ns-addr"      = { ipv4 = local.hub_eu_ns_addr }
    "${local.hub_prefix}eu-nva-vm-addr"  = { ipv4 = local.hub_eu_nva_vm_addr }
    "${local.hub_prefix}eu-nva-ilb-addr" = { ipv4 = local.hub_eu_nva_ilb_addr }
    "${local.hub_prefix}eu-ilb-addr"     = { ipv4 = local.hub_eu_ilb_addr }
    "${local.hub_prefix}eu-alb-addr"     = { ipv4 = local.hub_eu_alb_addr }
  }
  hub_us_main_addresses = {
    "${local.hub_prefix}us-ncc-cr-addr0" = { ipv4 = local.hub_us_ncc_cr_addr0 }
    "${local.hub_prefix}us-ncc-cr-addr1" = { ipv4 = local.hub_us_ncc_cr_addr1 }
    "${local.hub_prefix}us-router-addr"  = { ipv4 = local.hub_us_router_addr }
    "${local.hub_prefix}us-ns-addr"      = { ipv4 = local.hub_us_ns_addr }
    "${local.hub_prefix}us-nva-vm-addr"  = { ipv4 = local.hub_us_nva_vm_addr }
    "${local.hub_prefix}us-nva-ilb-addr" = { ipv4 = local.hub_us_nva_ilb_addr }
    "${local.hub_prefix}us-ilb-addr"     = { ipv4 = local.hub_us_ilb_addr }
    "${local.hub_prefix}us-alb-addr"     = { ipv4 = local.hub_us_alb_addr }
  }

  hub_us_gke_master_cidr1 = "172.16.11.32/28"
  hub_us_gke_master_cidr2 = "172.16.11.48/28"
  hub_us_psa_range1       = "10.1.220.0/22"
  hub_us_psa_range2       = "10.1.224.0/22"

  hub_us_main_default_gw = cidrhost(local.hub_subnets_us["us-main"].ip_cidr_range, 1)
  hub_us_vm_addr         = cidrhost(local.hub_subnets_us["us-main"].ip_cidr_range, 9)
  hub_us_router_addr     = cidrhost(local.hub_subnets_us["us-main"].ip_cidr_range, 10)
  hub_us_ncc_cr_addr0    = cidrhost(local.hub_subnets_us["us-main"].ip_cidr_range, 20)
  hub_us_ncc_cr_addr1    = cidrhost(local.hub_subnets_us["us-main"].ip_cidr_range, 30)
  hub_us_ns_addr         = cidrhost(local.hub_subnets_us["us-main"].ip_cidr_range, 40)
  hub_us_nva_vm_addr     = cidrhost(local.hub_subnets_us["us-main"].ip_cidr_range, 50)
  hub_us_nva_ilb_addr    = cidrhost(local.hub_subnets_us["us-main"].ip_cidr_range, 60)
  hub_us_ilb_addr        = cidrhost(local.hub_subnets_us["us-main"].ip_cidr_range, 70)
  hub_us_alb_addr        = cidrhost(local.hub_subnets_us["us-main"].ip_cidr_range, 80)
  hub_us_router_lo_addr  = "22.22.22.22"

  # psc/api
  hub_psc_api_fr_range    = "10.1.0.0/24"                           # vip range
  hub_psc_api_all_fr_name = "${var.prefix}huball"                   # all-apis forwarding rule name
  hub_psc_api_sec_fr_name = "${var.prefix}hubsec"                   # vpc-sc forwarding rule name
  hub_psc_api_all_fr_addr = cidrhost(local.hub_psc_api_fr_range, 1) # all-apis forwarding rule vip
  hub_psc_api_sec_fr_addr = cidrhost(local.hub_psc_api_fr_range, 2) # vpc-sc forwarding rule vip

  # psc/api http(s) service controls
  hub_eu_psc_https_ctrl_run_dns = "${local.hub_eu_region}-run.googleapis.com"
  hub_us_psc_https_ctrl_run_dns = "${local.hub_us_region}-run.googleapis.com"

  # psc endpoints ( to spoke1 published services)
  hub_eu_ep_spoke1_eu_psc_ilb_prefix = "ep.eu.spoke1-eu-ilb"
  hub_eu_ep_spoke1_eu_psc_nlb_prefix = "ep.eu.spoke1-eu-nlb"
  hub_eu_ep_spoke1_eu_psc_alb_prefix = "ep.eu.spoke1-eu-alb"
  hub_eu_ep_spoke1_eu_psc_ilb_fqdn   = "${local.hub_eu_ep_spoke1_eu_psc_ilb_prefix}.${local.hub_dns_zone}"
  hub_eu_ep_spoke1_eu_psc_nlb_fqdn   = "${local.hub_eu_ep_spoke1_eu_psc_nlb_prefix}.${local.hub_dns_zone}"
  hub_eu_ep_spoke1_eu_psc_alb_fqdn   = "${local.hub_eu_ep_spoke1_eu_psc_alb_prefix}.${local.hub_dns_zone}"

  # hub_us_ep_spoke1_us_psc_ilb_prefix = "ep.us.spoke1-eu-ilb"
  # hub_us_ep_spoke1_us_psc_nlb_prefix = "ep.us.spoke1-eu-nlb"
  # hub_us_ep_spoke1_us_psc_alb_prefix = "ep.us.spoke1-eu-alb"
  # hub_us_ep_spoke1_us_psc_ilb_fqdn   = "${local.hub_us_ep_spoke1_us_psc_ilb_prefix}.${local.hub_dns_zone}"
  # hub_us_ep_spoke1_us_psc_nlb_fqdn   = "${local.hub_us_ep_spoke1_us_psc_nlb_prefix}.${local.hub_dns_zone}"
  # hub_us_ep_spoke1_us_psc_alb_fqdn   = "${local.hub_us_ep_spoke1_us_psc_alb_prefix}.${local.hub_dns_zone}"

  # fqdn
  hub_geo_ilb_prefix = "ilb.geo" # geo-dns resolves to regional ilb endpoint
  hub_geo_ilb_fqdn   = "${local.hub_geo_ilb_prefix}.${local.hub_dns_zone}"

  hub_eu_vm_dns_prefix  = "vm.eu"
  hub_eu_ilb_dns_prefix = "ilb.eu"
  hub_eu_alb_dns_prefix = "alb.eu"
  hub_eu_vm_fqdn        = "${local.hub_eu_vm_dns_prefix}.${local.hub_dns_zone}"
  hub_eu_ilb_fqdn       = "${local.hub_eu_ilb_dns_prefix}.${local.hub_dns_zone}"
  hub_eu_alb_fqdn       = "${local.hub_eu_alb_dns_prefix}.${local.hub_dns_zone}"

  hub_us_vm_dns_prefix  = "vm.us"
  hub_us_ilb_dns_prefix = "ilb.us"
  hub_us_alb_dns_prefix = "alb.us"
  hub_us_vm_fqdn        = "${local.hub_us_vm_dns_prefix}.${local.hub_dns_zone}"
  hub_us_ilb_fqdn       = "${local.hub_us_ilb_dns_prefix}.${local.hub_dns_zone}"
  hub_us_alb_fqdn       = "${local.hub_us_alb_dns_prefix}.${local.hub_dns_zone}"

  # td
  hub_td_range                       = "172.16.0.0/24"
  hub_td_envoy_cloud_addr            = cidrhost(local.hub_td_range, 2)
  hub_td_envoy_hybrid_addr           = cidrhost(local.hub_td_range, 3)
  hub_td_grpc_cloud_svc              = "grpc-cloud"
  hub_td_envoy_cloud_svc             = "envoy-cloud"
  hub_td_envoy_hybrid_svc            = "envoy-hybrid"
  hub_td_envoy_bridge_ilb_dns_prefix = "ilb.envoy-bridge" # geo-dns resolves to regional endpoint
}

# spoke1
#=====================================================

locals {
  spoke1_prefix      = var.prefix == "" ? "spoke1-" : join("-", [var.prefix, "spoke1-"])
  spoke1_bucket_name = "${local.spoke1_prefix}${var.project_id_spoke1}-bucket"
  spoke1_asn         = "65411"
  spoke1_eu_region   = local.region1
  spoke1_us_region   = local.region2
  spoke1_supernet    = "10.11.0.0/16"
  spoke1_domain      = "spoke1"
  spoke1_dns_zone    = "${local.spoke1_domain}.${local.cloud_domain}"

  spoke1_subnets                  = merge(local.spoke1_subnets_eu, local.spoke1_subnets_us)
  spoke1_subnets_list             = [for k, v in local.spoke1_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == null]
  spoke1_subnets_private_nat_list = [for k, v in local.spoke1_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == "PRIVATE_NAT"]
  spoke1_subnets_proxy_only_list  = [for k, v in local.spoke1_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == "REGIONAL_MANAGED_PROXY"]
  spoke1_subnets_psc_list         = [for k, v in local.spoke1_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == "PRIVATE_SERVICE_CONNECT"]

  spoke1_subnets_eu = {
    eu-main         = { region = local.spoke1_eu_region, ip_cidr_range = "10.11.11.0/24", ipv6 = {}, enable_private_access = true, subnet_flow_logs = true }
    eu-gke          = { region = local.spoke1_eu_region, ip_cidr_range = "10.11.12.0/24", ipv6 = {}, enable_private_access = true, secondary_ip_ranges = { pods = "10.11.100.0/23", services = "10.11.102.0/24" } }
    eu-reg-proxy    = { region = local.spoke1_eu_region, ip_cidr_range = "10.11.13.0/24", ipv6 = {}, enable_private_access = false, purpose = "REGIONAL_MANAGED_PROXY", role = "ACTIVE" }
    eu-psc-ilb-nat  = { region = local.spoke1_eu_region, ip_cidr_range = "10.11.14.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-ilb-nat6 = { region = local.spoke1_eu_region, ip_cidr_range = "10.11.15.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-nlb-nat  = { region = local.spoke1_eu_region, ip_cidr_range = "10.11.16.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-nlb-nat6 = { region = local.spoke1_eu_region, ip_cidr_range = "10.11.17.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-alb-nat  = { region = local.spoke1_eu_region, ip_cidr_range = "10.11.18.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-alb-nat6 = { region = local.spoke1_eu_region, ip_cidr_range = "10.11.19.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
  }
  spoke1_subnets_us = {
    us-main         = { region = local.spoke1_us_region, ip_cidr_range = "10.11.21.0/24", ipv6 = {}, enable_private_access = true }
    us-gke          = { region = local.spoke1_us_region, ip_cidr_range = "10.11.22.0/24", ipv6 = {}, enable_private_access = true, secondary_ip_ranges = { pods = "10.11.200.0/23", services = "10.11.202.0/24" } }
    us-reg-proxy    = { region = local.spoke1_us_region, ip_cidr_range = "10.11.23.0/24", ipv6 = {}, enable_private_access = false, purpose = "REGIONAL_MANAGED_PROXY", role = "ACTIVE" }
    us-psc-ilb-nat  = { region = local.spoke1_us_region, ip_cidr_range = "10.11.24.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-ilb-nat6 = { region = local.spoke1_us_region, ip_cidr_range = "10.11.25.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-nlb-nat  = { region = local.spoke1_us_region, ip_cidr_range = "10.11.26.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-nlb-nat6 = { region = local.spoke1_us_region, ip_cidr_range = "10.11.27.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-alb-nat  = { region = local.spoke1_us_region, ip_cidr_range = "10.11.28.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-alb-nat6 = { region = local.spoke1_us_region, ip_cidr_range = "10.11.29.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
  }

  spoke1_gke_master_cidr1     = "172.16.11.0/28"
  spoke1_gke_master_cidr2     = "172.16.11.16/28"
  spoke1_eu_psa_range1        = "10.11.120.0/22"
  spoke1_eu_psa_range2        = "10.11.124.0/22"
  spoke1_psc_api_fr_range     = "10.11.0.0/24" # vip range
  spoke1_eu_psc4_producer_nat = "192.168.101.0/24"
  spoke1_us_psc4_producer_nat = "192.168.102.0/24"

  spoke1_eu_main_default_gw = cidrhost(local.spoke1_subnets["eu-main"].ip_cidr_range, 1)
  spoke1_eu_vm_addr         = cidrhost(local.spoke1_subnets["eu-main"].ip_cidr_range, 9)
  spoke1_eu_ilb_addr        = cidrhost(local.spoke1_subnets["eu-main"].ip_cidr_range, 30)
  spoke1_eu_nlb_addr        = cidrhost(local.spoke1_subnets["eu-main"].ip_cidr_range, 40)
  spoke1_eu_alb_addr        = cidrhost(local.spoke1_subnets["eu-main"].ip_cidr_range, 50)

  spoke1_us_main_default_gw = cidrhost(local.spoke1_subnets["us-main"].ip_cidr_range, 1)
  spoke1_us_vm_addr         = cidrhost(local.spoke1_subnets["us-main"].ip_cidr_range, 9)
  spoke1_us_ilb_addr        = cidrhost(local.spoke1_subnets["us-main"].ip_cidr_range, 30)
  spoke1_us_alb_addr        = cidrhost(local.spoke1_subnets["us-main"].ip_cidr_range, 40)

  spoke1_eu_main_addresses = {
    "${local.spoke1_prefix}eu-ilb-addr" = { ipv4 = local.spoke1_eu_ilb_addr }
    "${local.spoke1_prefix}eu-alb-addr" = { ipv4 = local.spoke1_eu_alb_addr }
  }
  spoke1_us_main_addresses = {
    "${local.spoke1_prefix}us-ilb-addr" = { ipv4 = local.spoke1_us_ilb_addr }
    "${local.spoke1_prefix}us-alb-addr" = { ipv4 = local.spoke1_us_alb_addr }
  }

  # fqdn
  spoke1_eu_vm_dns_prefix  = "vm.eu"
  spoke1_eu_ilb_dns_prefix = "ilb.eu"
  spoke1_eu_nlb_dns_prefix = "nlb.eu"
  spoke1_eu_alb_dns_prefix = "alb.eu"
  spoke1_eu_vm_fqdn        = "${local.spoke1_eu_vm_dns_prefix}.${local.spoke1_dns_zone}"
  spoke1_eu_ilb_fqdn       = "${local.spoke1_eu_ilb_dns_prefix}.${local.spoke1_dns_zone}"
  spoke1_eu_nlb_fqdn       = "${local.spoke1_eu_nlb_dns_prefix}.${local.spoke1_dns_zone}"
  spoke1_eu_alb_fqdn       = "${local.spoke1_eu_alb_dns_prefix}.${local.spoke1_dns_zone}"

  spoke1_us_vm_dns_prefix  = "vm.us"
  spoke1_us_ilb_dns_prefix = "ilb.us"
  spoke1_us_nlb_dns_prefix = "nlb.us"
  spoke1_us_alb_dns_prefix = "alb.us"
  spoke1_us_vm_fqdn        = "${local.spoke1_us_vm_dns_prefix}.${local.spoke1_dns_zone}"
  spoke1_us_ilb_fqdn       = "${local.spoke1_us_ilb_dns_prefix}.${local.spoke1_dns_zone}"
  spoke1_us_nlb_fqdn       = "${local.spoke1_us_nlb_dns_prefix}.${local.spoke1_dns_zone}"
  spoke1_us_alb_fqdn       = "${local.spoke1_us_alb_dns_prefix}.${local.spoke1_dns_zone}"

  # psc/api
  spoke1_psc_api_all_fr_name = "${var.prefix}spoke1all"                   # all-apis forwarding rule name
  spoke1_psc_api_sec_fr_name = "${var.prefix}spoke1sec"                   # vpc-sc forwarding rule name
  spoke1_psc_api_all_fr_addr = cidrhost(local.spoke1_psc_api_fr_range, 1) # all-apis forwarding rule vip
  spoke1_psc_api_sec_fr_addr = cidrhost(local.spoke1_psc_api_fr_range, 2) # vpc-sc forwarding rule vip

  # psc/api http(s) service controls
  spoke1_eu_psc_https_ctrl_run_dns = "${local.spoke1_eu_region}-run.googleapis.com"
  spoke1_us_psc_https_ctrl_run_dns = "${local.spoke1_us_region}-run.googleapis.com"

  # reverse dns
  spoke1_eu_ilb_reverse_suffix = format("%s.%s.${local.spoke1_reverse_zone}",
    element(split(".", local.spoke1_eu_ilb_addr), 3),
    element(split(".", local.spoke1_eu_ilb_addr), 2)
  )
  spoke1_eu_alb_reverse_suffix = format("%s.%s.${local.spoke1_reverse_zone}",
    element(split(".", local.spoke1_eu_alb_addr), 3),
    element(split(".", local.spoke1_eu_alb_addr), 2)
  )
  spoke1_reverse_zone = format("%s.%s.in-addr.arpa.",
    element(split(".", local.spoke1_supernet), 1),
    element(split(".", local.spoke1_supernet), 0)
  )
}

# spoke2
#=====================================================

locals {
  spoke2_prefix      = var.prefix == "" ? "spoke2-" : join("-", [var.prefix, "spoke2-"])
  spoke2_bucket_name = "${local.spoke2_prefix}${var.project_id_spoke2}-bucket"
  spoke2_asn         = "65422"
  spoke2_eu_region   = local.region1
  spoke2_us_region   = local.region2
  spoke2_supernet    = "10.22.0.0/16"
  spoke2_domain      = "spoke2"
  spoke2_dns_zone    = "${local.spoke2_domain}.${local.cloud_domain}"

  spoke2_subnets                  = merge(local.spoke2_subnets_eu, local.spoke2_subnets_us)
  spoke2_subnets_list             = [for k, v in local.spoke2_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == null]
  spoke2_subnets_private_nat_list = [for k, v in local.spoke2_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == "PRIVATE_NAT"]
  spoke2_subnets_proxy_only_list  = [for k, v in local.spoke2_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == "REGIONAL_MANAGED_PROXY"]
  spoke2_subnets_psc_list         = [for k, v in local.spoke2_subnets : merge({ name = k }, v) if lookup(v, "purpose", null) == "PRIVATE_SERVICE_CONNECT"]

  spoke2_subnets_eu = {
    eu-main         = { region = local.spoke2_eu_region, ip_cidr_range = "10.22.11.0/24", ipv6 = {}, enable_private_access = true }
    eu-gke          = { region = local.spoke2_eu_region, ip_cidr_range = "10.22.12.0/24", ipv6 = {}, enable_private_access = true, secondary_ip_ranges = { pods = "10.22.100.0/23", services = "10.22.102.0/24" } }
    eu-reg-proxy    = { region = local.spoke2_eu_region, ip_cidr_range = "10.22.13.0/24", ipv6 = {}, enable_private_access = false, purpose = "REGIONAL_MANAGED_PROXY", role = "ACTIVE" }
    eu-psc-ilb-nat  = { region = local.spoke2_eu_region, ip_cidr_range = "10.22.14.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-ilb-nat6 = { region = local.spoke2_eu_region, ip_cidr_range = "10.22.15.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-nlb-nat  = { region = local.spoke2_eu_region, ip_cidr_range = "10.22.16.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-nlb-nat6 = { region = local.spoke2_eu_region, ip_cidr_range = "10.22.17.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-alb-nat  = { region = local.spoke2_eu_region, ip_cidr_range = "10.22.18.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    eu-psc-alb-nat6 = { region = local.spoke2_eu_region, ip_cidr_range = "10.22.19.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
  }
  spoke2_subnets_us = {
    us-main         = { region = local.spoke2_us_region, ip_cidr_range = "10.22.21.0/24", ipv6 = {}, enable_private_access = true }
    us-gke          = { region = local.spoke2_us_region, ip_cidr_range = "10.22.22.0/24", ipv6 = {}, enable_private_access = true, secondary_ip_ranges = { pods = "10.22.200.0/23", services = "10.22.202.0/24" } }
    us-reg-proxy    = { region = local.spoke2_us_region, ip_cidr_range = "10.22.23.0/24", ipv6 = {}, enable_private_access = false, purpose = "REGIONAL_MANAGED_PROXY", role = "ACTIVE" }
    us-psc-ilb-nat  = { region = local.spoke2_us_region, ip_cidr_range = "10.22.24.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-ilb-nat6 = { region = local.spoke2_us_region, ip_cidr_range = "10.22.25.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-nlb-nat  = { region = local.spoke2_us_region, ip_cidr_range = "10.22.26.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-nlb-nat6 = { region = local.spoke2_us_region, ip_cidr_range = "10.22.27.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-alb-nat  = { region = local.spoke2_us_region, ip_cidr_range = "10.22.28.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
    us-psc-alb-nat6 = { region = local.spoke2_us_region, ip_cidr_range = "10.22.29.0/24", ipv6 = {}, enable_private_access = false, purpose = "PRIVATE_SERVICE_CONNECT" }
  }

  spoke2_gke_master_cidr1     = "172.16.22.0/28"
  spoke2_gke_master_cidr2     = "172.16.22.16/28"
  spoke2_us_psa_range1        = "10.22.120.0/22"
  spoke2_us_psa_range2        = "10.22.124.0/22"
  spoke2_psc_api_fr_range     = "10.22.0.0/24" # vip range
  spoke2_eu_psc4_producer_nat = "192.168.201.0/24"
  spoke2_us_psc4_producer_nat = "192.168.202.0/24"

  spoke2_eu_main_default_gw           = cidrhost(local.spoke2_subnets["eu-main"].ip_cidr_range, 1)
  spoke2_eu_vm_addr                   = cidrhost(local.spoke2_subnets["eu-main"].ip_cidr_range, 9)
  spoke2_eu_ilb_addr                  = cidrhost(local.spoke2_subnets["eu-main"].ip_cidr_range, 30)
  spoke2_eu_nlb_addr                  = cidrhost(local.spoke2_subnets["eu-main"].ip_cidr_range, 40)
  spoke2_eu_alb_addr                  = cidrhost(local.spoke2_subnets["eu-main"].ip_cidr_range, 50)
  spoke2_eu_ep_spoke1_eu_psc_ilb_addr = cidrhost(local.spoke2_subnets["eu-main"].ip_cidr_range, 60)
  spoke2_eu_ep_spoke1_eu_psc_nlb_addr = cidrhost(local.spoke2_subnets["eu-main"].ip_cidr_range, 70)
  spoke2_eu_ep_spoke1_eu_psc_alb_addr = cidrhost(local.spoke2_subnets["eu-main"].ip_cidr_range, 80)

  spoke2_us_main_default_gw           = cidrhost(local.spoke2_subnets["us-main"].ip_cidr_range, 1)
  spoke2_us_vm_addr                   = cidrhost(local.spoke2_subnets["us-main"].ip_cidr_range, 9)
  spoke2_us_ilb_addr                  = cidrhost(local.spoke2_subnets["us-main"].ip_cidr_range, 30)
  spoke2_us_nlb_addr                  = cidrhost(local.spoke2_subnets["us-main"].ip_cidr_range, 40)
  spoke2_us_alb_addr                  = cidrhost(local.spoke2_subnets["us-main"].ip_cidr_range, 50)
  spoke2_us_ep_spoke1_eu_psc_ilb_addr = cidrhost(local.spoke2_subnets["us-main"].ip_cidr_range, 60)
  spoke2_us_ep_spoke1_eu_psc_nlb_addr = cidrhost(local.spoke2_subnets["us-main"].ip_cidr_range, 70)
  spoke2_us_ep_spoke1_eu_psc_alb_addr = cidrhost(local.spoke2_subnets["us-main"].ip_cidr_range, 80)

  spoke2_eu_main_addresses = {
    "${local.spoke2_prefix}eu-ilb-addr" = { ipv4 = local.spoke2_eu_ilb_addr }
    "${local.spoke2_prefix}eu-alb-addr" = { ipv4 = local.spoke2_eu_alb_addr }
  }
  spoke2_us_main_addresses = {
    "${local.spoke2_prefix}us-ilb-addr" = { ipv4 = local.spoke2_us_ilb_addr }
    "${local.spoke2_prefix}us-alb-addr" = { ipv4 = local.spoke2_us_alb_addr }
  }

  # fqdn
  spoke2_eu_vm_dns_prefix  = "vm.eu"
  spoke2_eu_ilb_dns_prefix = "ilb.eu"
  spoke2_eu_nlb_dns_prefix = "nlb.eu"
  spoke2_eu_alb_dns_prefix = "alb.eu"
  spoke2_eu_vm_fqdn        = "${local.spoke2_eu_vm_dns_prefix}.${local.spoke2_dns_zone}"
  spoke2_eu_ilb_fqdn       = "${local.spoke2_eu_ilb_dns_prefix}.${local.spoke2_dns_zone}"
  spoke2_eu_nlb_fqdn       = "${local.spoke2_eu_nlb_dns_prefix}.${local.spoke2_dns_zone}"
  spoke2_eu_alb_fqdn       = "${local.spoke2_eu_alb_dns_prefix}.${local.spoke2_dns_zone}"

  spoke2_us_vm_dns_prefix  = "vm.us"
  spoke2_us_ilb_dns_prefix = "ilb.us"
  spoke2_us_nlb_dns_prefix = "nlb.us"
  spoke2_us_alb_dns_prefix = "alb.us"
  spoke2_us_vm_fqdn        = "${local.spoke2_us_vm_dns_prefix}.${local.spoke2_dns_zone}"
  spoke2_us_ilb_fqdn       = "${local.spoke2_us_ilb_dns_prefix}.${local.spoke2_dns_zone}"
  spoke2_us_nlb_fqdn       = "${local.spoke2_us_nlb_dns_prefix}.${local.spoke2_dns_zone}"
  spoke2_us_alb_fqdn       = "${local.spoke2_us_alb_dns_prefix}.${local.spoke2_dns_zone}"

  # psc/api
  spoke2_psc_api_all_fr_name = "${var.prefix}spoke2all"                   # all-apis forwarding rule name
  spoke2_psc_api_sec_fr_name = "${var.prefix}spoke2sec"                   # vpc-sc forwarding rule name
  spoke2_psc_api_all_fr_addr = cidrhost(local.spoke2_psc_api_fr_range, 1) # all-apis forwarding rule vip
  spoke2_psc_api_sec_fr_addr = cidrhost(local.spoke2_psc_api_fr_range, 2) # vpc-sc forwarding rule vip

  # psc/api http(s) service controls
  spoke2_eu_psc_https_ctrl_run_dns = "${local.spoke2_eu_region}-run.googleapis.com"
  spoke2_us_psc_https_ctrl_run_dns = "${local.spoke2_us_region}-run.googleapis.com"

  # psc endpoints --> spoke1
  spoke2_eu_ep_spoke1_eu_psc_ilb_prefix = "ep.eu.spoke1-eu-ilb"
  spoke2_eu_ep_spoke1_eu_psc_nlb_prefix = "ep.eu.spoke1-eu-nlb"
  spoke2_eu_ep_spoke1_eu_psc_alb_prefix = "ep.eu.spoke1-eu-alb"
  spoke2_eu_ep_spoke1_eu_psc_ilb_fqdn   = "${local.spoke2_eu_ep_spoke1_eu_psc_ilb_prefix}.${local.spoke2_dns_zone}"
  spoke2_eu_ep_spoke1_eu_psc_nlb_fqdn   = "${local.spoke2_eu_ep_spoke1_eu_psc_nlb_prefix}.${local.spoke2_dns_zone}"
  spoke2_eu_ep_spoke1_eu_psc_alb_fqdn   = "${local.spoke2_eu_ep_spoke1_eu_psc_alb_prefix}.${local.spoke2_dns_zone}"

  # reverse dns
  spoke2_us_ilb_reverse_suffix = format("%s.%s.${local.spoke2_reverse_zone}",
    element(split(".", local.spoke2_us_ilb_addr), 3),
    element(split(".", local.spoke2_us_ilb_addr), 2)
  )
  spoke2_us_alb_reverse_suffix = format("%s.%s.${local.spoke2_reverse_zone}",
    element(split(".", local.spoke2_us_alb_addr), 3),
    element(split(".", local.spoke2_us_alb_addr), 2)
  )
  spoke2_reverse_zone = format("%s.%s.in-addr.arpa.",
    element(split(".", local.spoke2_supernet), 1),
    element(split(".", local.spoke2_supernet), 0)
  )
}
