
# hub
####################################################

resource "google_network_connectivity_hub" "ncc_hub" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}ncc-hub"
  description = "ncc hub"
  labels = {
    lab = local.hub_prefix
  }
}

# spoke1 (site1 vpn)
####################################################

resource "google_network_connectivity_spoke" "ncc_spoke1" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}ncc-spoke1"
  hub         = google_network_connectivity_hub.ncc_hub.id
  location    = local.site1_region
  description = "site1"
  linked_vpn_tunnels {
    uris = [
      module.vpn_hub_eu_to_site1.tunnel_self_links["t0"],
      module.vpn_hub_eu_to_site1.tunnel_self_links["t1"]
    ]
    site_to_site_data_transfer = true
  }
}

# spoke2 (site2 vpn)
####################################################

resource "google_network_connectivity_spoke" "ncc_spoke2" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}ncc-spoke2"
  hub         = google_network_connectivity_hub.ncc_hub.id
  location    = local.site2_region
  description = "site2"
  linked_vpn_tunnels {
    uris = [
      module.vpn_hub_us_to_site2.tunnel_self_links["t0"],
      module.vpn_hub_us_to_site2.tunnel_self_links["t1"]
    ]
    site_to_site_data_transfer = true
  }
}
