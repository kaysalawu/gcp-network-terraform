
locals {
  ncc_advertised_prefixes = ["${(local.supernet)}=supernet", ]
}

# routers
#------------------------------------

# eu

resource "google_compute_router" "hub_eu_ncc_cr" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-ncc-cr"
  network = module.hub_vpc.self_link
  region  = local.hub_eu_region
  bgp {
    asn               = local.hub_eu_ncc_cr_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# us

resource "google_compute_router" "hub_us_ncc_cr" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}us-ncc-cr"
  network = module.hub_vpc.self_link
  region  = local.hub_us_region
  bgp {
    asn               = local.hub_us_ncc_cr_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# hub
#---------------------------------

resource "google_network_connectivity_hub" "ncc_hub" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}ncc-hub"
  description = "ncc hub"
  labels = {
    lab = local.hub_prefix
  }
}

# spoke1 (site1 appliance)
#---------------------------------

# spoke

resource "google_network_connectivity_spoke" "ncc_spoke1" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}ncc-spoke1"
  hub         = google_network_connectivity_hub.ncc_hub.id
  location    = local.site1_region
  description = "site1"
  linked_router_appliance_instances {
    instances {
      virtual_machine = google_compute_instance.hub_eu_router.self_link
      ip_address      = google_compute_instance.hub_eu_router.network_interface.0.network_ip
    }
    site_to_site_data_transfer = true
  }
}

# interface

resource "google_compute_router_interface" "ncc_hub_eu_router_0" {
  provider            = google-beta
  project             = var.project_id_hub
  name                = "${google_compute_instance.hub_eu_router.name}-0"
  region              = local.hub_eu_region
  router              = google_compute_router.hub_eu_ncc_cr.name
  subnetwork          = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  private_ip_address  = local.hub_eu_ncc_cr_addr0
  redundant_interface = google_compute_router_interface.ncc_hub_eu_router_1.name
}

resource "google_compute_router_interface" "ncc_hub_eu_router_1" {
  provider           = google-beta
  project            = var.project_id_hub
  name               = "${google_compute_instance.hub_eu_router.name}-1"
  region             = local.hub_eu_region
  router             = google_compute_router.hub_eu_ncc_cr.name
  subnetwork         = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  private_ip_address = local.hub_eu_ncc_cr_addr1
}

# bgp peer

resource "google_compute_router_peer" "ncc_hub_eu_router_0" {
  provider                  = google-beta
  project                   = var.project_id_hub
  region                    = local.hub_eu_region
  name                      = "${google_compute_instance.hub_eu_router.name}-0"
  interface                 = google_compute_router_interface.ncc_hub_eu_router_0.name
  router                    = google_compute_router.hub_eu_ncc_cr.name
  router_appliance_instance = google_compute_instance.hub_eu_router.self_link
  peer_ip_address           = google_compute_instance.hub_eu_router.network_interface.0.network_ip
  peer_asn                  = local.hub_eu_router_asn
  advertised_route_priority = 155
  advertise_mode            = "CUSTOM"

  advertised_ip_ranges {
    range       = local.supernet
    description = "supernet"
  }
}

resource "google_compute_router_peer" "ncc_hub_eu_router_1" {
  provider                  = google-beta
  project                   = var.project_id_hub
  region                    = local.hub_eu_region
  name                      = "${google_compute_instance.hub_eu_router.name}-1"
  interface                 = google_compute_router_interface.ncc_hub_eu_router_1.name
  router                    = google_compute_router.hub_eu_ncc_cr.name
  router_appliance_instance = google_compute_instance.hub_eu_router.self_link
  peer_ip_address           = google_compute_instance.hub_eu_router.network_interface.0.network_ip
  peer_asn                  = local.hub_eu_router_asn
  advertised_route_priority = 155
  advertise_mode            = "CUSTOM"

  advertised_ip_ranges {
    range       = local.supernet
    description = "supernet"
  }
}

# spoke2 (site2 appliance)
#---------------------------------

# spoke

resource "google_network_connectivity_spoke" "ncc_spoke2" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}ncc-spoke2"
  hub         = google_network_connectivity_hub.ncc_hub.id
  location    = local.site2_region
  description = "site2"
  linked_router_appliance_instances {
    instances {
      virtual_machine = google_compute_instance.hub_us_router.self_link
      ip_address      = google_compute_instance.hub_us_router.network_interface.0.network_ip
    }
    site_to_site_data_transfer = true
  }
}

# interface

resource "google_compute_router_interface" "ncc_hub_us_router_0" {
  provider            = google-beta
  project             = var.project_id_hub
  name                = "${google_compute_instance.hub_us_router.name}-0"
  region              = local.hub_us_region
  router              = google_compute_router.hub_us_ncc_cr.name
  subnetwork          = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
  private_ip_address  = local.hub_us_ncc_cr_addr0
  redundant_interface = google_compute_router_interface.ncc_hub_us_router_1.name
}

resource "google_compute_router_interface" "ncc_hub_us_router_1" {
  provider           = google-beta
  project            = var.project_id_hub
  name               = "${google_compute_instance.hub_us_router.name}-1"
  region             = local.hub_us_region
  router             = google_compute_router.hub_us_ncc_cr.name
  subnetwork         = module.hub_vpc.subnet_self_links["${local.hub_us_region}/us-main"]
  private_ip_address = local.hub_us_ncc_cr_addr1
}

# bgp peer

resource "google_compute_router_peer" "ncc_hub_us_router_0" {
  provider                  = google-beta
  project                   = var.project_id_hub
  region                    = local.hub_us_region
  name                      = "${google_compute_instance.hub_us_router.name}-0"
  interface                 = google_compute_router_interface.ncc_hub_us_router_0.name
  router                    = google_compute_router.hub_us_ncc_cr.name
  router_appliance_instance = google_compute_instance.hub_us_router.self_link
  peer_ip_address           = google_compute_instance.hub_us_router.network_interface.0.network_ip
  peer_asn                  = local.hub_us_router_asn
  advertised_route_priority = 155
  advertise_mode            = "CUSTOM"

  advertised_ip_ranges {
    range       = local.supernet
    description = "supernet"
  }
}

resource "google_compute_router_peer" "ncc_hub_us_router_1" {
  provider                  = google-beta
  project                   = var.project_id_hub
  region                    = local.hub_us_region
  name                      = "${google_compute_instance.hub_us_router.name}-1"
  interface                 = google_compute_router_interface.ncc_hub_us_router_1.name
  router                    = google_compute_router.hub_us_ncc_cr.name
  router_appliance_instance = google_compute_instance.hub_us_router.self_link
  peer_ip_address           = google_compute_instance.hub_us_router.network_interface.0.network_ip
  peer_asn                  = local.hub_us_router_asn
  advertised_route_priority = 155
  advertise_mode            = "CUSTOM"

  advertised_ip_ranges {
    range       = local.supernet
    description = "supernet"
  }
}
