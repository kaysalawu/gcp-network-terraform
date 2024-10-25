
locals {
  advertised_prefixes = {
    site1_to_hub = { (local.site1_supernet) = "site1 supernet" }
    site2_to_hub = { (local.site2_supernet) = "site2 supernet" }
    hub_to_site1 = { (local.supernet) = "supernet" }
    hub_to_site2 = { (local.supernet) = "supernet" }
  }
  advertised_prefixes_ipv6 = {
    site1_to_hub = { (local.site1_vpc_ipv6_cidr) = "site1 ipv6" }
    site2_to_hub = { (local.site2_vpc_ipv6_cidr) = "site2 ipv6" }
    hub_to_site1 = { (local.hub_vpc_ipv6_cidr) = "hub ipv6", (local.spoke1_vpc_ipv6_cidr) = "spoke1 ipv6", (local.spoke2_vpc_ipv6_cidr) = "spoke2 ipv6" }
    hub_to_site2 = { (local.hub_vpc_ipv6_cidr) = "hub ipv6", (local.spoke1_vpc_ipv6_cidr) = "spoke1 ipv6", (local.spoke2_vpc_ipv6_cidr) = "spoke2 ipv6" }
  }
}

# routers
#------------------------------

# site1

resource "google_compute_router" "site1_vpn_cr" {
  project = var.project_id_onprem
  name    = "${local.site1_prefix}vpn-cr"
  network = module.site1_vpc.self_link
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
  network = module.site2_vpc.self_link
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
  network = module.hub_vpc.self_link
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
  network = module.hub_vpc.self_link
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
  project    = var.project_id_onprem
  name       = "${local.site1_prefix}gw"
  network    = module.site1_vpc.self_link
  region     = local.site1_region
  stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
}

resource "google_compute_ha_vpn_gateway" "site2_gw" {
  project    = var.project_id_onprem
  name       = "${local.site2_prefix}gw"
  network    = module.site2_vpc.self_link
  region     = local.site2_region
  stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
}

# hub

resource "google_compute_ha_vpn_gateway" "hub_eu_gw" {
  project    = var.project_id_hub
  name       = "${local.hub_prefix}eu-gw"
  network    = module.hub_vpc.self_link
  region     = local.hub_eu_region
  stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
}

resource "google_compute_ha_vpn_gateway" "hub_us_gw" {
  project    = var.project_id_hub
  name       = "${local.hub_prefix}us-gw"
  network    = module.hub_vpc.self_link
  region     = local.hub_us_region
  stack_type = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
}

# hub / site1
#------------------------------

# hub

module "vpn_hub_eu_to_site1" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha?ref=v34.1.0"
  project_id         = var.project_id_hub
  region             = local.hub_eu_region
  network            = module.hub_vpc.self_link
  name               = "eu--site1"
  vpn_gateway_create = null
  vpn_gateway        = google_compute_ha_vpn_gateway.hub_eu_gw.self_link
  peer_gateways = {
    default = { gcp = google_compute_ha_vpn_gateway.site1_gw.self_link }
  }
  router_config = {
    create = false
    name   = google_compute_router.hub_eu_vpn_cr.name
    asn    = local.hub_eu_vpn_cr_asn
  }

  tunnels = {
    t0 = {
      bgp_peer = {
        address = cidrhost(local.bgp_range1, 1)
        asn     = local.site1_asn
        ipv6 = {
          nexthop_address      = cidrhost(local.bgp_range1_ipv6, 2)
          peer_nexthop_address = cidrhost(local.bgp_range1_ipv6, 1)
        }
        custom_advertise = {
          route_priority = 100
          all_subnets    = false
          ip_ranges = merge(
            local.advertised_prefixes.hub_to_site1,
            local.advertised_prefixes_ipv6.hub_to_site1
          )
        }
      }
      bgp_session_range     = "${cidrhost(local.bgp_range1, 2)}/30"
      ike_version           = 2
      vpn_gateway_interface = 0
      router                = google_compute_router.hub_eu_vpn_cr.name
      shared_secret         = local.psk
    }
    t1 = {
      bgp_peer = {
        address = cidrhost(local.bgp_range2, 1)
        asn     = local.site1_asn
        ipv6 = {
          nexthop_address      = cidrhost(local.bgp_range2_ipv6, 2)
          peer_nexthop_address = cidrhost(local.bgp_range2_ipv6, 1)
        }
        custom_advertise = {
          route_priority = 100
          all_subnets    = false
          ip_ranges = merge(
            local.advertised_prefixes.hub_to_site1,
            local.advertised_prefixes_ipv6.hub_to_site1
          )
        }
      }
      bgp_session_range     = "${cidrhost(local.bgp_range2, 2)}/30"
      ike_version           = 2
      vpn_gateway_interface = 1
      router                = google_compute_router.hub_eu_vpn_cr.name
      shared_secret         = local.psk
    }
  }
}

# site1

module "vpn_site1_to_hub_eu" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha?ref=v34.1.0"
  project_id         = var.project_id_onprem
  region             = local.site1_region
  network            = module.site1_vpc.self_link
  name               = "site1--hub-eu"
  vpn_gateway_create = null
  vpn_gateway        = google_compute_ha_vpn_gateway.site1_gw.self_link
  peer_gateways = {
    default = { gcp = google_compute_ha_vpn_gateway.hub_eu_gw.self_link }
  }
  router_config = {
    create = false
    name   = google_compute_router.site1_vpn_cr.name
    asn    = local.site1_asn
  }

  tunnels = {
    t0 = {
      bgp_peer = {
        address = cidrhost(local.bgp_range1, 2)
        asn     = local.hub_eu_vpn_cr_asn
        ipv6 = {
          nexthop_address      = cidrhost(local.bgp_range1_ipv6, 1)
          peer_nexthop_address = cidrhost(local.bgp_range1_ipv6, 2)
        }
        custom_advertise = {
          route_priority = 100
          all_subnets    = false
          ip_ranges = merge(
            local.advertised_prefixes.site1_to_hub,
            local.advertised_prefixes_ipv6.site1_to_hub
          )
        }
      }
      bgp_session_range     = "${cidrhost(local.bgp_range1, 1)}/30"
      ike_version           = 2
      vpn_gateway_interface = 0
      router                = google_compute_router.site1_vpn_cr.name
      shared_secret         = local.psk
    }
    t1 = {
      bgp_peer = {
        address = cidrhost(local.bgp_range2, 2)
        asn     = local.hub_eu_vpn_cr_asn
        ipv6 = {
          nexthop_address      = cidrhost(local.bgp_range2_ipv6, 1)
          peer_nexthop_address = cidrhost(local.bgp_range2_ipv6, 2)
        }
        custom_advertise = {
          route_priority = 100
          all_subnets    = false
          ip_ranges = merge(
            local.advertised_prefixes.site1_to_hub,
            local.advertised_prefixes_ipv6.site1_to_hub
          )
        }
      }
      bgp_session_range     = "${cidrhost(local.bgp_range2, 1)}/30"
      ike_version           = 2
      vpn_gateway_interface = 1
      router                = google_compute_router.site1_vpn_cr.name
      shared_secret         = local.psk
    }
  }
}

# hub / site2
#------------------------------

# hub

module "vpn_hub_us_to_site2" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha?ref=v34.1.0"
  project_id         = var.project_id_hub
  region             = local.hub_us_region
  network            = module.hub_vpc.self_link
  name               = "eu--site2"
  vpn_gateway_create = null
  vpn_gateway        = google_compute_ha_vpn_gateway.hub_us_gw.self_link
  peer_gateways = {
    default = { gcp = google_compute_ha_vpn_gateway.site2_gw.self_link }
  }
  router_config = {
    create = false
    name   = google_compute_router.hub_us_vpn_cr.name
    asn    = local.hub_us_vpn_cr_asn
  }
  tunnels = {
    t0 = {
      bgp_peer = {
        address = cidrhost(local.bgp_range3, 1)
        asn     = local.site2_asn
        ipv6 = {
          nexthop_address      = cidrhost(local.bgp_range1_ipv6, 4)
          peer_nexthop_address = cidrhost(local.bgp_range1_ipv6, 3)
        }
        custom_advertise = {
          route_priority = 100
          all_subnets    = false
          ip_ranges = merge(
            local.advertised_prefixes.hub_to_site2,
            local.advertised_prefixes_ipv6.hub_to_site2
          )
        }
      }
      bgp_session_range     = "${cidrhost(local.bgp_range3, 2)}/30"
      vpn_gateway_interface = 0
      router                = google_compute_router.hub_us_vpn_cr.name
      shared_secret         = local.psk
    }
    t1 = {
      bgp_peer = {
        address = cidrhost(local.bgp_range4, 1)
        asn     = local.site2_asn
        ipv6 = {
          nexthop_address      = cidrhost(local.bgp_range2_ipv6, 4)
          peer_nexthop_address = cidrhost(local.bgp_range2_ipv6, 3)
        }
        custom_advertise = {
          route_priority = 100
          all_subnets    = false
          ip_ranges = merge(
            local.advertised_prefixes.hub_to_site2,
            local.advertised_prefixes_ipv6.hub_to_site2
          )
        }
      }
      bgp_session_range     = "${cidrhost(local.bgp_range4, 2)}/30"
      vpn_gateway_interface = 1
      router                = google_compute_router.hub_us_vpn_cr.name
      shared_secret         = local.psk
    }
  }
}

# site2

module "vpn_site2_to_hub_us" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha?ref=v34.1.0"
  project_id         = var.project_id_onprem
  region             = local.site2_region
  network            = module.site2_vpc.self_link
  name               = "site2--hub-us"
  vpn_gateway_create = null
  vpn_gateway        = google_compute_ha_vpn_gateway.site2_gw.self_link
  peer_gateways = {
    default = { gcp = google_compute_ha_vpn_gateway.hub_us_gw.self_link }
  }
  router_config = {
    create = false
    name   = google_compute_router.site2_vpn_cr.name
    asn    = local.site2_asn
  }

  tunnels = {
    t0 = {
      bgp_peer = {
        address = cidrhost(local.bgp_range3, 2)
        asn     = local.hub_us_vpn_cr_asn
        ipv6 = {
          nexthop_address      = cidrhost(local.bgp_range1_ipv6, 3)
          peer_nexthop_address = cidrhost(local.bgp_range1_ipv6, 4)
        }
        custom_advertise = {
          route_priority = 100
          all_subnets    = false
          ip_ranges = merge(
            local.advertised_prefixes.site2_to_hub,
            local.advertised_prefixes_ipv6.site2_to_hub
          )
        }
      }
      bgp_session_range     = "${cidrhost(local.bgp_range3, 1)}/30"
      vpn_gateway_interface = 0
      router                = google_compute_router.site2_vpn_cr.name
      shared_secret         = local.psk
    }
    t1 = {
      bgp_peer = {
        address = cidrhost(local.bgp_range4, 2)
        asn     = local.hub_us_vpn_cr_asn
        ipv6 = {
          nexthop_address      = cidrhost(local.bgp_range2_ipv6, 3)
          peer_nexthop_address = cidrhost(local.bgp_range2_ipv6, 4)
        }
        custom_advertise = {
          route_priority = 100
          all_subnets    = false
          ip_ranges = merge(
            local.advertised_prefixes.site2_to_hub,
            local.advertised_prefixes_ipv6.site2_to_hub
          )
        }
      }
      bgp_session_range     = "${cidrhost(local.bgp_range4, 1)}/30"
      vpn_gateway_interface = 1
      router                = google_compute_router.site2_vpn_cr.name
      shared_secret         = local.psk
    }
  }
}

