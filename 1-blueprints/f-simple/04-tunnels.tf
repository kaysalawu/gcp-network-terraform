
locals {
  advertised_prefixes = {
    site1_to_hub = { (local.site1_supernet) = "site1 supernet" }
    site2_to_hub = { (local.site2_supernet) = "site2 supernet" }
    hub_to_site1 = { (local.supernet) = "supernet" }
    hub_to_site2 = { (local.supernet) = "supernet" }
  }
}

# routers
#------------------------------

# site1

resource "google_compute_router" "site1_vpn_cr" {
  project = var.project_id_onprem
  name    = "${local.site1_prefix}vpn-cr"
  network = google_compute_network.site1_vpc.self_link
  region  = local.site1_region
  bgp {
    asn               = local.site1_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# site2

resource "google_compute_router" "site2_vpn_cr" {
  project = var.project_id_onprem
  name    = "${local.site2_prefix}vpn-cr"
  network = google_compute_network.site2_vpc.self_link
  region  = local.site2_region
  bgp {
    asn               = local.site2_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# hub

resource "google_compute_router" "hub_eu_vpn_cr" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-vpn-cr"
  network = google_compute_network.hub_vpc.self_link
  region  = local.hub_eu_region
  bgp {
    asn               = local.hub_eu_vpn_cr_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

resource "google_compute_router" "hub_us_vpn_cr" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}us-vpn-cr"
  network = google_compute_network.hub_vpc.self_link
  region  = local.hub_us_region
  bgp {
    asn               = local.hub_us_vpn_cr_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# vpn gateways
#------------------------------

# onprem

resource "google_compute_ha_vpn_gateway" "site1_gw" {
  project = var.project_id_onprem
  name    = "${local.site1_prefix}gw"
  network = google_compute_network.site1_vpc.self_link
  region  = local.site1_region
}

resource "google_compute_ha_vpn_gateway" "site2_gw" {
  project = var.project_id_onprem
  name    = "${local.site2_prefix}gw"
  network = google_compute_network.site2_vpc.self_link
  region  = local.site2_region
}

# hub

resource "google_compute_ha_vpn_gateway" "hub_eu_gw" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-gw"
  network = google_compute_network.hub_vpc.self_link
  region  = local.hub_eu_region
}

resource "google_compute_ha_vpn_gateway" "hub_us_gw" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}us-gw"
  network = google_compute_network.hub_vpc.self_link
  region  = local.hub_us_region
}

# hub / site1
#------------------------------

# hub

module "vpn_hub_eu_to_site1" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha?ref=v15.0.0"
  project_id         = var.project_id_hub
  region             = local.hub_eu_region
  network            = google_compute_network.hub_vpc.self_link
  name               = "${local.hub_prefix}eu-to-site1"
  vpn_gateway        = google_compute_ha_vpn_gateway.hub_eu_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.site1_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.hub_eu_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr1, 1)
        asn     = local.site1_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.hub_to_site1
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr1, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.hub_eu_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr2, 1)
        asn     = local.site1_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.hub_to_site1
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr2, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.hub_eu_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# site1

module "vpn_site1_to_hub_eu" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha?ref=v15.0.0"
  project_id         = var.project_id_onprem
  region             = local.site1_region
  network            = google_compute_network.site1_vpc.self_link
  name               = "${local.site1_prefix}to-hub-eu"
  vpn_gateway        = google_compute_ha_vpn_gateway.site1_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.hub_eu_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.site1_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr1, 2)
        asn     = local.hub_eu_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.site1_to_hub
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr1, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.site1_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr2, 2)
        asn     = local.hub_eu_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.site1_to_hub
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr2, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.site1_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# hub / site2
#------------------------------

# hub

module "vpn_hub_us_to_site2" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha?ref=v15.0.0"
  project_id         = var.project_id_hub
  region             = local.hub_us_region
  network            = google_compute_network.hub_vpc.self_link
  name               = "${local.hub_prefix}us-to-site2"
  vpn_gateway        = google_compute_ha_vpn_gateway.hub_us_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.site2_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.hub_us_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr3, 1)
        asn     = local.site2_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.hub_to_site2
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr3, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.hub_us_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr4, 1)
        asn     = local.site2_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.hub_to_site2
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr4, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.hub_us_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# site2

module "vpn_site2_to_hub_us" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha?ref=v15.0.0"
  project_id         = var.project_id_onprem
  region             = local.site2_region
  network            = google_compute_network.site2_vpc.self_link
  name               = "${local.site2_prefix}to-hub-us"
  vpn_gateway        = google_compute_ha_vpn_gateway.site2_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.hub_us_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.site2_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr3, 2)
        asn     = local.hub_us_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.site2_to_hub
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr3, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.site2_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr4, 2)
        asn     = local.hub_us_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.site2_to_hub
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr4, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.site2_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}
