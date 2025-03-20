
# netblocks

data "google_netblock_ip_ranges" "dns_forwarders" { range_type = "dns-forwarders" }
data "google_netblock_ip_ranges" "private_googleapis" { range_type = "private-googleapis" }
data "google_netblock_ip_ranges" "restricted_googleapis" { range_type = "restricted-googleapis" }
data "google_netblock_ip_ranges" "health_checkers" { range_type = "health-checkers" }
data "google_netblock_ip_ranges" "iap_forwarders" { range_type = "iap-forwarders" }

# common
#=====================================================

locals {
  netblocks_internal = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "100.64.0.0/10",
  ]
  netblocks_iap            = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
  netblocks_restricted_api = ["199.36.153.4/30", ]
  netblocks_private_api    = ["199.36.153.8/30", ]
  netblocks_dns            = data.google_netblock_ip_ranges.dns_forwarders.cidr_blocks_ipv4
  # global internet negs
  # dig TXT _cloud-eoips.googleusercontent.com | grep -Eo 'ip4:[^ ]+' | cut -d':' -f2
  netblocks_gfe = concat(
    data.google_netblock_ip_ranges.health_checkers.cidr_blocks_ipv4, [
      "34.96.0.0/20",
      "34.127.192.0/18",
  ])
  netblocks_internal_ipv6       = ["fd20::/20", ]
  netblocks_iap_ipv6            = ["2600:2d00:1:7::/64", ]
  netblocks_restricted_api_ipv6 = ["2600:2d00:0002:1000::/64", ]
  netblocks_private_api_ipv6    = ["2600:2d00:0002:2000::/64", ]
  netblocks_gfe_ipv6 = [
    "2600:2d00:1:b029::/64",
    "2600:2d00:1:1::/64",
    "2600:1901:8001::/48",
  ]

  ports_accessible_from_internet = {
    "http"    = 80
    "https"   = 443
    "maestro" = 3000
    "gateway" = 8000
    "machina" = 8008
    "sheet"   = 8080
    "plotter" = 9000
  }
}
