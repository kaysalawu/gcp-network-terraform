
locals {
  hub_eu_psc_ep_auradb = cidrhost(local.hub_subnets_eu["eu-main"].ip_cidr_range, 60)
}

####################################################
# psc endpoints --> spoke1
####################################################

# ipv4
#--------------------------------------

# ilb

resource "google_compute_address" "hub_eu_psc_aura_fr" {
  provider     = google-beta
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-psc-aura-fr"
  region       = local.hub_eu_region
  subnetwork   = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-main"]
  address      = local.hub_eu_psc_ep_auradb
  address_type = "INTERNAL"
  ip_version   = "IPV4"
}

# resource "google_compute_forwarding_rule" "hub_eu_psc_aura_fr" {
#   provider              = google-beta
#   project               = var.project_id_hub
#   name                  = "${local.hub_prefix}eu-psc-aura-fr"
#   region                = local.hub_eu_region
#   network               = module.hub_vpc.self_link
#   target                = module.spoke1_eu_ilb.service_attachment_ids["fr-ipv4"]
#   ip_address            = google_compute_address.hub_eu_psc_spoke1_eu_ilb_fr_ipv4.id
#   load_balancing_scheme = ""
# }
