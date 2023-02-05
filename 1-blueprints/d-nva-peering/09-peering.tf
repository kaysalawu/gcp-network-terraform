
# vpc peering
#------------------------------------

# hub

resource "google_compute_network_peering" "peering_hub_int_to_spoke1" {
  name         = "${local.hub_prefix}int-to-spoke1"
  network      = google_compute_network.hub_int_vpc.self_link
  peer_network = google_compute_network.spoke1_vpc.self_link

  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "peering_hub_int_to_spoke2" {
  name         = "${local.hub_prefix}int-to-spoke2"
  network      = google_compute_network.hub_int_vpc.self_link
  peer_network = google_compute_network.spoke2_vpc.self_link

  export_custom_routes = true
  import_custom_routes = true
}

# spoke1

resource "google_compute_network_peering" "peering_spoke1_to_hub" {
  name         = "${local.spoke1_prefix}to-hub-int"
  network      = google_compute_network.spoke1_vpc.self_link
  peer_network = google_compute_network.hub_int_vpc.self_link

  export_custom_routes = true
  import_custom_routes = true
}

# spoke2

resource "google_compute_network_peering" "peering_spoke2_to_hub" {
  name         = "${local.spoke2_prefix}to-hub-int"
  network      = google_compute_network.spoke2_vpc.self_link
  peer_network = google_compute_network.hub_int_vpc.self_link

  export_custom_routes = true
  import_custom_routes = true
}
