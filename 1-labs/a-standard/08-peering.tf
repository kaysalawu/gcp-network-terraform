
# vpc peering
#------------------------------------

# hub

resource "google_compute_network_peering" "peering_hub_to_spoke1" {
  name         = "${local.hub_prefix}to-spoke1"
  network      = module.hub_vpc.self_link
  peer_network = module.spoke1_vpc.self_link

  export_custom_routes = true
  import_custom_routes = true

  export_subnet_routes_with_public_ip = true
  import_subnet_routes_with_public_ip = true
}

# spoke1

resource "google_compute_network_peering" "peering_spoke1_to_hub" {
  name         = "${local.spoke1_prefix}to-hub"
  network      = module.spoke1_vpc.self_link
  peer_network = module.hub_vpc.self_link

  export_custom_routes = true
  import_custom_routes = true

  export_subnet_routes_with_public_ip = true
  import_subnet_routes_with_public_ip = true
}
