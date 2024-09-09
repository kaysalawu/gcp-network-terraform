
# routers
#------------------------------

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
  project = var.project_id_onprem
  name    = "${local.site1_prefix}gw"
  network = module.site1_vpc.self_link
  region  = local.site1_region
}

resource "google_compute_ha_vpn_gateway" "site2_gw" {
  project = var.project_id_onprem
  name    = "${local.site2_prefix}gw"
  network = module.site2_vpc.self_link
  region  = local.site2_region
}

# hub

resource "google_compute_ha_vpn_gateway" "hub_eu_gw" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-gw"
  network = module.hub_vpc.self_link
  region  = local.hub_eu_region
}

resource "google_compute_ha_vpn_gateway" "hub_us_gw" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}us-gw"
  network = module.hub_vpc.self_link
  region  = local.hub_us_region
}

# hub / site1
#------------------------------

# hub

locals {
  hub_eu_router_startup = templatefile("../../scripts/vyos/vyos.sh", {
    PASSWORD         = "Password123"
    LOCAL_ASN        = local.hub_eu_router_asn
    LOOPBACK_IP      = local.hub_eu_router_lo_addr
    ENABLE_BGP       = true
    BGP_USE_LOOPBACK = true
    STATIC_ROUTES    = []
    IPSEC_CONFIG     = { enable = true, interface = "eth0" }
    DNAT_CONFIG = [{
      enable              = true
      rule                = 10
      outbound_interface  = "eth0"
      destination_address = local.hub_psc_api_fr_addr
      translation_address = local.hub_eu_router_addr
    }]
    TUNNELS = []
    VPN_TUNNELS = [{
      enable         = true
      name           = "SITE-TUN0"
      local_vti      = "vti0"
      local_auth_id  = local.hub_eu_router_addr
      local_address  = local.hub_eu_router_addr
      local_vti_ip   = cidrhost(local.bgp_range1, 2)
      local_vti_mask = split("/", local.bgp_range1).1
      local_type     = "respond"
      peer_auth_id   = local.site1_router_addr
      peer_nat_ip    = google_compute_address.site1_router.address
      psk            = local.psk
    }]
    PREFIX_LISTS = [
      { enable = true, name = "PL-OUT-SITE", prefix = local.supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-IN-SITE", prefix = local.site1_supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-OUT-CR", prefix = local.site1_supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-IN-CR", prefix = local.supernet, rule = 10, action = "permit" },
    ]
    AS_LISTS = [
      { enable = true, name = "AL-OUT-SITE", rule = 10, regex = "_16550_", action = "deny" },
      { enable = true, name = "AL-OUT-SITE", rule = 20, regex = "_", action = "permit" },
      { enable = true, name = "AL-IN-SITE", rule = 10, regex = "_16550_", action = "deny" },
      { enable = true, name = "AL-IN-SITE", rule = 20, regex = "_", action = "permit" },
      { enable = true, name = "AL-OUT-CR", rule = 10, regex = "_", action = "permit" },
      { enable = true, name = "AL-IN-CR", rule = 10, regex = "_", action = "permit" },
    ]
    ROUTE_MAPS = [
      #{ enable = true, name = "MAP-OUT-SITE", type = "as-list", list = "AL-OUT-SITE", set_metric = 100, rule = 10, action = "permit" },
      #{ enable = true, name = "MAP-IN-SITE", type = "as-list", list = "AL-IN-SITE", set_metric = 100, rule = 10, action = "permit" },
      #{ enable = true, name = "MAP-OUT-CR", type = "as-list", list = "AL-OUT-CR", set_metric = 100, rule = 10, action = "permit" },
      #{ enable = true, name = "MAP-IN-CR", type = "as-list", list = "AL-IN-CR", set_metric = 100, rule = 10, action = "permit" },
      { enable = true, name = "MAP-OUT-SITE", type = "pf-list", list = "PL-OUT-SITE", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-IN-SITE", type = "pf-list", list = "PL-IN-SITE", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-OUT-CR", type = "pf-list", list = "PL-OUT-CR", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-IN-CR", type = "pf-list", list = "PL-IN-CR", set_metric = 105, rule = 20, action = "permit" },
    ]
    BGP_SESSIONS = [
      {
        peer_asn         = local.site1_asn
        peer_ip          = cidrhost(local.bgp_range1, 1)
        multihop         = { enable = true, ttl = 4 }
        route_map_export = { enable = true, map = "MAP-OUT-SITE" }
        route_map_import = { enable = true, map = "MAP-IN-SITE" }
      },
      {
        peer_asn         = local.hub_eu_ncc_cr_asn
        peer_ip          = local.hub_eu_ncc_cr_addr0
        multihop         = { enable = true, ttl = 4 }
        route_map_export = { enable = true, map = "MAP-OUT-CR" }
        route_map_import = { enable = true, map = "MAP-IN-CR" }
      },
      {
        peer_asn         = local.hub_eu_ncc_cr_asn
        peer_ip          = local.hub_eu_ncc_cr_addr1
        multihop         = { enable = true, ttl = 4 }
        route_map_export = { enable = true, map = "MAP-OUT-CR" }
        route_map_import = { enable = true, map = "MAP-IN-CR" }
      }
    ]
    BGP_REDISTRIBUTE_STATIC = { enable = false, metric = 90 }
    BGP_ADVERTISED_NETWORKS = []
  })
}

resource "google_compute_instance" "hub_eu_router" {
  project        = var.project_id_hub
  name           = "${local.hub_prefix}eu-router"
  machine_type   = "e2-medium"
  zone           = "${local.hub_eu_region}-b"
  tags           = [local.tag_router]
  can_ip_forward = true

  params {
    resource_manager_tags = {
      (local.hub_vpc_tags_dns.parent) = local.hub_vpc_tags_dns.id
      (local.hub_vpc_tags_nva.parent) = local.hub_vpc_tags_nva.id
    }
  }
  boot_disk {
    initialize_params {
      image = var.image_vyos
      size  = 20
      type  = "pd-ssd"
    }
  }
  network_interface {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
    network_ip = local.hub_eu_router_addr
    access_config {
      nat_ip = google_compute_address.hub_eu_router.address
    }
  }
  service_account {
    scopes = ["cloud-platform"]
  }
  metadata = {
    serial-port-enable = "TRUE"
    user-data          = local.hub_eu_router_startup
  }
}

# site1

locals {
  site1_router_startup = templatefile("../../scripts/vyos/vyos.sh", {
    PASSWORD         = "Password123"
    LOCAL_ASN        = local.site1_asn
    LOOPBACK_IP      = local.site1_router_lo_addr
    ENABLE_BGP       = true
    BGP_USE_LOOPBACK = true
    STATIC_ROUTES = [{
      destination = local.site1_supernet
      next_hop    = cidrhost(local.site1_subnets.main.ip_cidr_range, 1)
    }]
    IPSEC_CONFIG = { enable = true, interface = "eth0" }
    DNAT_CONFIG = [{
      enable              = false
      rule                = 10
      outbound_interface  = "eth0"
      destination_address = ""
      translation_address = ""
    }]
    TUNNELS = []
    VPN_TUNNELS = [{
      enable         = true
      name           = "HUB-TUN0"
      local_vti      = "vti0"
      local_auth_id  = local.site1_router_addr
      local_address  = local.site1_router_addr
      local_vti_ip   = cidrhost(local.bgp_range1, 1)
      local_vti_mask = split("/", local.bgp_range1).1
      local_type     = "initiate"
      peer_auth_id   = local.hub_eu_router_addr
      peer_nat_ip    = google_compute_address.hub_eu_router.address
      psk            = local.psk
    }]
    PREFIX_LISTS = [
      { enable = true, name = "PL-OUT-HUB", prefix = local.site1_supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-IN-HUB", prefix = local.supernet, rule = 10, action = "permit" },
    ]
    AS_LISTS = [
      { enable = true, name = "AL-OUT-HUB", rule = 10, regex = "_", action = "permit" },
      { enable = true, name = "AL-IN-HUB", rule = 10, regex = "_", action = "permit" },
    ]
    ROUTE_MAPS = [
      { enable = true, name = "MAP-OUT-HUB", type = "as-list", list = "AL-OUT-HUB", set_metric = 100, rule = 10, action = "permit" },
      { enable = true, name = "MAP-OUT-HUB", type = "pf-list", list = "PL-OUT-HUB", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-IN-HUB", type = "as-list", list = "AL-IN-HUB", set_metric = 100, rule = 10, action = "permit" },
      { enable = true, name = "MAP-IN-HUB", type = "pf-list", list = "PL-IN-HUB", set_metric = 105, rule = 20, action = "permit" },
    ]
    BGP_SESSIONS = [{
      peer_asn         = local.hub_eu_router_asn
      peer_ip          = cidrhost(local.bgp_range1, 2)
      multihop         = { enable = true, ttl = 4 }
      route_map_export = { enable = true, map = "MAP-OUT-HUB" }
      route_map_import = { enable = true, map = "MAP-IN-HUB" }
    }]
    BGP_REDISTRIBUTE_STATIC = { enable = true, metric = 90 }
    BGP_ADVERTISED_NETWORKS = []
  })
}

resource "google_compute_instance" "site1_router" {
  project        = var.project_id_onprem
  name           = "${local.site1_prefix}router"
  machine_type   = "e2-medium"
  zone           = "${local.site1_region}-b"
  tags           = [local.tag_router]
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = var.image_vyos
      size  = 20
      type  = "pd-ssd"
    }
  }
  network_interface {
    network    = module.site1_vpc.self_link
    subnetwork = module.site1_vpc.subnet_self_links["${local.site1_region}/main"]
    network_ip = local.site1_router_addr
    access_config {
      nat_ip = google_compute_address.site1_router.address
    }
  }
  service_account {
    scopes = ["cloud-platform"]
  }
  metadata = {
    serial-port-enable = "TRUE"
    user-data          = local.site1_router_startup
  }
}

## static routes

locals {
  site1_router_routes = { "supernet" = local.supernet }
}

resource "google_compute_route" "site1_router_routes" {
  for_each               = local.site1_router_routes
  provider               = google-beta
  project                = var.project_id_onprem
  name                   = "${local.site1_prefix}${each.key}"
  dest_range             = each.value
  network                = module.site1_vpc.self_link
  next_hop_instance      = google_compute_instance.site1_router.id
  next_hop_instance_zone = "${local.site1_region}-b"
  priority               = "100"
}

# hub / site2
#------------------------------

# hub

locals {
  hub_us_router_startup = templatefile("../../scripts/vyos/vyos.sh", {
    PASSWORD         = "Password123"
    LOCAL_ASN        = local.hub_us_router_asn
    LOOPBACK_IP      = local.hub_us_router_lo_addr
    ENABLE_BGP       = true
    BGP_USE_LOOPBACK = true
    STATIC_ROUTES    = []
    IPSEC_CONFIG     = { enable = true, interface = "eth0" }
    DNAT_CONFIG = [{
      enable              = true
      rule                = 10
      outbound_interface  = "eth0"
      destination_address = local.hub_psc_api_fr_addr
      translation_address = local.hub_us_router_addr
    }]
    TUNNELS = []
    VPN_TUNNELS = [{
      enable         = true
      name           = "SITE-TUN0"
      local_vti      = "vti0"
      local_auth_id  = local.hub_us_router_addr
      local_address  = local.hub_us_router_addr
      local_vti_ip   = cidrhost(local.bgp_range2, 2)
      local_vti_mask = split("/", local.bgp_range2).1
      local_type     = "respond"
      peer_auth_id   = local.site2_router_addr
      peer_nat_ip    = google_compute_address.site2_router.address
      psk            = local.psk
    }]
    PREFIX_LISTS = [
      { enable = true, name = "PL-OUT-SITE", prefix = local.supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-IN-SITE", prefix = local.site2_supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-OUT-CR", prefix = local.site2_supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-IN-CR", prefix = local.supernet, rule = 10, action = "permit" },
    ]
    AS_LISTS = [
      { enable = true, name = "AL-OUT-SITE", rule = 10, regex = "_16550_", action = "deny" },
      { enable = true, name = "AL-OUT-SITE", rule = 20, regex = "_", action = "permit" },
      { enable = true, name = "AL-IN-SITE", rule = 10, regex = "_16550_", action = "deny" },
      { enable = true, name = "AL-IN-SITE", rule = 20, regex = "_", action = "permit" },
      { enable = true, name = "AL-OUT-CR", rule = 10, regex = "_", action = "permit" },
      { enable = true, name = "AL-IN-CR", rule = 10, regex = "_", action = "permit" },
    ]
    ROUTE_MAPS = [
      #{ enable = true, name = "MAP-OUT-SITE", type = "as-list", list = "AL-OUT-SITE", set_metric = 100, rule = 10, action = "permit" },
      #{ enable = true, name = "MAP-IN-SITE", type = "as-list", list = "AL-IN-SITE", set_metric = 100, rule = 10, action = "permit" },
      #{ enable = true, name = "MAP-OUT-CR", type = "as-list", list = "AL-OUT-CR", set_metric = 100, rule = 10, action = "permit" },
      #{ enable = true, name = "MAP-IN-CR", type = "as-list", list = "AL-IN-CR", set_metric = 100, rule = 10, action = "permit" },
      { enable = true, name = "MAP-OUT-SITE", type = "pf-list", list = "PL-OUT-SITE", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-IN-SITE", type = "pf-list", list = "PL-IN-SITE", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-OUT-CR", type = "pf-list", list = "PL-OUT-CR", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-IN-CR", type = "pf-list", list = "PL-IN-CR", set_metric = 105, rule = 20, action = "permit" },
    ]
    BGP_SESSIONS = [
      {
        peer_asn         = local.site2_asn
        peer_ip          = cidrhost(local.bgp_range2, 1)
        multihop         = { enable = false, ttl = 4 }
        route_map_export = { enable = true, map = "MAP-OUT-SITE" }
        route_map_import = { enable = true, map = "MAP-IN-SITE" }
      },
      {
        peer_asn         = local.hub_us_ncc_cr_asn
        peer_ip          = local.hub_us_ncc_cr_addr0
        multihop         = { enable = true, ttl = 4 }
        route_map_export = { enable = true, map = "MAP-OUT-CR" }
        route_map_import = { enable = true, map = "MAP-IN-CR" }
      },
      {
        peer_asn         = local.hub_us_ncc_cr_asn
        peer_ip          = local.hub_us_ncc_cr_addr1
        multihop         = { enable = true, ttl = 4 }
        route_map_export = { enable = true, map = "MAP-OUT-CR" }
        route_map_import = { enable = true, map = "MAP-IN-CR" }
      }
    ]
    BGP_REDISTRIBUTE_STATIC = { enable = false, metric = 90 }
    BGP_ADVERTISED_NETWORKS = []
  })
}

resource "google_compute_instance" "hub_us_router" {
  project        = var.project_id_hub
  name           = "${local.hub_prefix}us-router"
  machine_type   = "e2-medium"
  zone           = "${local.hub_us_region}-b"
  tags           = [local.tag_router]
  can_ip_forward = true

  params {
    resource_manager_tags = {
      (local.hub_vpc_tags_dns.parent) = local.hub_vpc_tags_dns.id
      (local.hub_vpc_tags_nva.parent) = local.hub_vpc_tags_nva.id
    }
  }
  boot_disk {
    initialize_params {
      image = var.image_vyos
      size  = 20
      type  = "pd-ssd"
    }
  }
  network_interface {
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
    network_ip = local.hub_us_router_addr
    access_config {
      nat_ip = google_compute_address.hub_us_router.address
    }
  }
  service_account {
    scopes = ["cloud-platform"]
  }
  metadata = {
    serial-port-enable = "TRUE"
    user-data          = local.hub_us_router_startup
  }
}

# site2

locals {
  site2_router_startup = templatefile("../../scripts/vyos/vyos.sh", {
    PASSWORD         = "Password123"
    LOCAL_ASN        = local.site2_asn
    LOOPBACK_IP      = local.site2_router_lo_addr
    ENABLE_BGP       = true
    BGP_USE_LOOPBACK = true
    STATIC_ROUTES = [
      {
        destination = local.site2_supernet
        next_hop    = cidrhost(local.site2_subnets.main.ip_cidr_range, 1)
    }]
    IPSEC_CONFIG = { enable = true, interface = "eth0" }
    DNAT_CONFIG = [{
      enable              = false
      rule                = 10
      outbound_interface  = "eth0"
      destination_address = ""
      translation_address = ""
    }]
    TUNNELS = []
    VPN_TUNNELS = [{
      enable         = true
      name           = "HUB-TUN0"
      local_vti      = "vti0"
      local_auth_id  = local.site2_router_addr
      local_address  = local.site2_router_addr
      local_vti_ip   = cidrhost(local.bgp_range2, 1)
      local_vti_mask = split("/", local.bgp_range2).1
      local_type     = "initiate"
      peer_auth_id   = local.hub_us_router_addr
      peer_nat_ip    = google_compute_address.hub_us_router.address
      psk            = local.psk
    }]
    PREFIX_LISTS = [
      { enable = true, name = "PL-OUT-HUB", prefix = local.site2_supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-IN-HUB", prefix = local.supernet, rule = 10, action = "permit" },
    ]
    AS_LISTS = [
      { enable = true, name = "AL-OUT-HUB", rule = 10, regex = "_", action = "permit" },
      { enable = true, name = "AL-IN-HUB", rule = 10, regex = "_", action = "permit" },
    ]
    ROUTE_MAPS = [
      { enable = true, name = "MAP-OUT-HUB", type = "as-list", list = "AL-OUT-HUB", set_metric = 100, rule = 10, action = "permit" },
      { enable = true, name = "MAP-OUT-HUB", type = "pf-list", list = "PL-OUT-HUB", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-IN-HUB", type = "as-list", list = "AL-IN-HUB", set_metric = 100, rule = 10, action = "permit" },
      { enable = true, name = "MAP-IN-HUB", type = "pf-list", list = "PL-IN-HUB", set_metric = 105, rule = 20, action = "permit" },
    ]
    BGP_SESSIONS = [{
      peer_asn         = local.hub_us_router_asn
      peer_ip          = cidrhost(local.bgp_range2, 2)
      multihop         = { enable = true, ttl = 4 }
      route_map_export = { enable = true, map = "MAP-OUT-HUB" }
      route_map_import = { enable = true, map = "MAP-IN-HUB" }
    }]
    BGP_REDISTRIBUTE_STATIC = { enable = true, metric = 90 }
    BGP_ADVERTISED_NETWORKS = []
  })
}

resource "google_compute_instance" "site2_router" {
  project        = var.project_id_onprem
  name           = "${local.site2_prefix}router"
  machine_type   = "e2-medium"
  zone           = "${local.site2_region}-b"
  tags           = [local.tag_router]
  can_ip_forward = true
  boot_disk {
    initialize_params {
      image = var.image_vyos
      size  = 20
      type  = "pd-ssd"
    }
  }
  network_interface {
    network    = module.site2_vpc.self_link
    subnetwork = module.site2_vpc.subnet_self_links["${local.site2_region}/main"]
    network_ip = local.site2_router_addr
    access_config {
      nat_ip = google_compute_address.site2_router.address
    }
  }
  service_account {
    scopes = ["cloud-platform"]
  }
  metadata = {
    serial-port-enable = "TRUE"
    user-data          = local.site2_router_startup
  }
}

# static routes

locals {
  site2_router_routes = { "supernet" = local.supernet }
}

resource "google_compute_route" "site2_router_routes" {
  for_each               = local.site2_router_routes
  provider               = google-beta
  project                = var.project_id_onprem
  name                   = "${local.site2_prefix}${each.key}"
  dest_range             = each.value
  network                = module.site2_vpc.self_link
  next_hop_instance      = google_compute_instance.site2_router.id
  next_hop_instance_zone = "${local.site2_region}-b"
  priority               = "100"
}

####################################################
# output files
####################################################

locals {
  tunnel_files = {
    "output/site1-router.sh"  = local.site1_router_startup
    "output/site2-router.sh"  = local.site2_router_startup
    "output/hub-us-router.sh" = local.hub_us_router_startup
    "output/hub-eu-router.sh" = local.hub_eu_router_startup
  }
}

resource "local_file" "tunnel_files" {
  for_each = local.tunnel_files
  filename = each.key
  content  = each.value
}
