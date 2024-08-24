
# psc/ilb producer
#---------------------------------

# nat subnet
/*
resource "google_compute_subnetwork" "spoke1_eu_psc_nat_subnet1" {
  provider      = google-beta
  project       = var.project_id_host
  name          = local.spoke1_eu_psc_nat_subnet1.name
  region        = local.spoke1_eu_region
  network       = google_compute_network.spoke1_vpc.self_link
  purpose       = "PRIVATE_SERVICE_CONNECT"
  ip_cidr_range = local.spoke1_eu_psc_nat_subnet1.ip_cidr_range
}*/

resource "google_compute_service_attachment" "spoke1_eu_svc_attach" {
  provider    = google-beta
  project     = var.project_id_host
  name        = "${local.spoke1_prefix}eu-svc-attach"
  region      = local.spoke1_eu_region
  description = "spoke1 eu psc service"

  enable_proxy_protocol = false
  connection_preference = "ACCEPT_AUTOMATIC"
  nat_subnets           = [google_compute_subnetwork.spoke1_eu_psc_nat_subnet1.name]
  target_service        = module.spoke1_eu_ilb_psc.forwarding_rule_id
}

# hub - psc/ilb consumer
#---------------------------------

resource "google_compute_address" "hub_ext_eu_psc_ep_addr" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}ext-eu-psc-ep-addr"
  region       = local.hub_eu_region
  subnetwork   = local.hub_ext_eu_subnet1_self_link
  address_type = "INTERNAL"
  address      = local.hub_ext_eu_psc_ep_addr
}

resource "google_compute_forwarding_rule" "hub_ext_eu_psc_fr" {
  provider   = google-beta
  project    = var.project_id_hub
  name       = "${local.hub_prefix}ext-eu-psc-fr"
  region     = local.hub_eu_region
  target     = google_compute_service_attachment.spoke1_eu_svc_attach.id
  network    = module.hub_ext_vpc.self_link
  ip_address = google_compute_address.hub_ext_eu_psc_ep_addr.id

  load_balancing_scheme = ""
}

# spoke2 - psc/ilb consumer
#---------------------------------

# endpoint address

resource "google_compute_address" "spoke2_eu_psc_ep_addr" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}eu-psc-ep-addr"
  region       = local.spoke2_eu_region
  subnetwork   = local.spoke2_eu_subnet1_self_link
  address_type = "INTERNAL"
  address      = local.spoke2_eu_psc_ep_addr
}

resource "google_compute_forwarding_rule" "spoke2_eu_psc_fr" {
  depends_on = [google_compute_forwarding_rule.hub_ext_eu_psc_fr]
  provider   = google-beta
  project    = var.project_id_spoke2
  name       = "${local.spoke2_prefix}eu-psc-fr"
  region     = local.spoke2_eu_region
  target     = google_compute_service_attachment.spoke1_eu_svc_attach.id
  network    = google_compute_network.spoke2_vpc.self_link
  ip_address = google_compute_address.spoke2_eu_psc_ep_addr.id

  load_balancing_scheme = ""
}
