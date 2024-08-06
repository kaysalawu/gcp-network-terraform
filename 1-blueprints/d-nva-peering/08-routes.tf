# routes
#------------------------------------

locals {
  hub_eu_ilb4_nva_routes = {
    ("${local.hub_prefix}eu-to-spoke1-supernet") = { priority = 100, dest = local.spoke1_supernet, }
    ("${local.hub_prefix}eu-to-mgt-eu-subnet1")  = { priority = 100, dest = local.hub_mgt_eu_subnet1.ip_cidr_range }
  }
  hub_us_ilb4_nva_routes = {
    ("${local.hub_prefix}us-to-spoke2-supernet") = { priority = 100, dest = local.spoke2_supernet }
    ("${local.hub_prefix}us-to-mgt-us-subnet1")  = { priority = 100, dest = local.hub_mgt_us_subnet1.ip_cidr_range }
  }
  hub_mgt_eu_ilb4_nva_routes = {
    ("${local.hub_prefix}mgt-eu-to-spoke1")         = { priority = 100, dest = local.spoke1_supernet }
    ("${local.hub_prefix}mgt-eu-to-site1")          = { priority = 100, dest = local.site1_supernet }
    ("${local.hub_prefix}mgt-eu-to-hub-eu-subnet1") = { priority = 100, dest = local.hub_eu_subnet1.ip_cidr_range }
    ("${local.hub_prefix}mgt-eu-to-hub-eu-subnet2") = { priority = 100, dest = local.hub_eu_subnet2.ip_cidr_range }
    ("${local.hub_prefix}mgt-eu-to-hub-eu-subnet3") = { priority = 100, dest = local.hub_eu_subnet3.ip_cidr_range }
  }
  hub_mgt_us_ilb4_nva_routes = {
    ("${local.hub_prefix}mgt-us-to-spoke2")         = { priority = 100, dest = local.spoke2_supernet }
    ("${local.hub_prefix}mgt-us-to-site2")          = { priority = 100, dest = local.site2_supernet }
    ("${local.hub_prefix}mgt-us-to-hub-us-subnet1") = { priority = 100, dest = local.hub_us_subnet1.ip_cidr_range }
    ("${local.hub_prefix}mgt-us-to-hub-us-subnet2") = { priority = 100, dest = local.hub_us_subnet2.ip_cidr_range }
    ("${local.hub_prefix}mgt-us-to-hub-us-subnet3") = { priority = 100, dest = local.hub_us_subnet3.ip_cidr_range }
  }
  hub_int_eu_ilb4_nva_routes_untagged = {
    ("${local.hub_prefix}int-eu-supernet-untagged") = { priority = 100, dest = local.supernet, }
  }
  hub_int_us_ilb4_nva_routes_untagged = {
    ("${local.hub_prefix}int-us-supernet-untagged") = { priority = 100, dest = local.supernet, }
  }
  spoke1_to_hub_int_eu_ilb4_nva_routes_tagged = {
    ("${local.spoke1_prefix}to-all-tagged") = { priority = 100, dest = local.supernet, tags = [local.tag_hub_int_eu_nva_ilb4] }
  }
  spoke2_to_hub_int_us_ilb4_nva_routes_tagged = {
    ("${local.spoke2_prefix}to-all-tagged") = { priority = 100, dest = local.supernet, tags = [local.tag_hub_int_us_nva_ilb4] }
  }
}

# hub (external) routes
#---------------------------------------

resource "google_compute_route" "hub_eu_ilb4" {
  for_each     = local.hub_eu_ilb4_nva_routes
  provider     = google-beta
  project      = var.project_id_hub
  name         = each.key
  dest_range   = each.value.dest
  network      = google_compute_network.hub_vpc.self_link
  next_hop_ilb = module.hub_eu_ilb4_nva.forwarding_rule_id
  tags         = try(each.value.tags, null)
  priority     = each.value.priority
}

resource "google_compute_route" "hub_us_ilb4" {
  for_each     = local.hub_us_ilb4_nva_routes
  provider     = google-beta
  project      = var.project_id_hub
  name         = each.key
  dest_range   = each.value.dest
  network      = google_compute_network.hub_vpc.self_link
  next_hop_ilb = module.hub_us_ilb4_nva.forwarding_rule_id
  tags         = try(each.value.tags, null)
  priority     = each.value.priority
}

# hub mgt routes
#---------------------------------------

resource "google_compute_route" "hub_mgt_eu_ilb4_nva" {
  for_each     = local.hub_mgt_eu_ilb4_nva_routes
  provider     = google-beta
  project      = var.project_id_hub
  name         = each.key
  dest_range   = each.value.dest
  network      = google_compute_network.hub_mgt_vpc.self_link
  next_hop_ilb = module.hub_mgt_eu_ilb4_nva.forwarding_rule_id
  tags         = try(each.value.tags, null)
  priority     = each.value.priority
}

resource "google_compute_route" "hub_mgt_us_ilb4_nva" {
  for_each     = local.hub_mgt_us_ilb4_nva_routes
  provider     = google-beta
  project      = var.project_id_hub
  name         = each.key
  dest_range   = each.value.dest
  network      = google_compute_network.hub_mgt_vpc.self_link
  next_hop_ilb = module.hub_mgt_us_ilb4_nva.forwarding_rule_id
  tags         = try(each.value.tags, null)
  priority     = each.value.priority
}

# hub (internal) routes
#---------------------------------------

resource "google_compute_route" "hub_int_eu_ilb4_nva_untagged" {
  for_each     = local.hub_int_eu_ilb4_nva_routes_untagged
  provider     = google-beta
  project      = var.project_id_hub
  name         = each.key
  dest_range   = each.value.dest
  network      = google_compute_network.hub_int_vpc.self_link
  next_hop_ilb = module.hub_int_eu_ilb4_nva.forwarding_rule_id
  tags         = try(each.value.tags, null)
  priority     = each.value.priority
}

resource "google_compute_route" "hub_int_us_ilb4_nva_untagged" {
  for_each     = local.hub_int_us_ilb4_nva_routes_untagged
  provider     = google-beta
  project      = var.project_id_hub
  name         = each.key
  dest_range   = each.value.dest
  network      = google_compute_network.hub_int_vpc.self_link
  next_hop_ilb = module.hub_int_us_ilb4_nva.forwarding_rule_id
  tags         = try(each.value.tags, null)
  priority     = each.value.priority
}

# spoke routes (tagged ilbanh)
#---------------------------------------

resource "google_compute_route" "spoke1_to_hub_int_eu_nva_ilb4_tagged" {
  for_each     = local.spoke1_to_hub_int_eu_ilb4_nva_routes_tagged
  provider     = google-beta
  project      = var.project_id_host
  name         = each.key
  dest_range   = each.value.dest
  network      = google_compute_network.spoke1_vpc.self_link
  next_hop_ilb = module.hub_int_eu_ilb4_nva.forwarding_rule_address
  tags         = try(each.value.tags, null)
  priority     = each.value.priority
}

resource "google_compute_route" "spoke2_to_hub_int_us_nva_ilb4_tagged" {
  for_each     = local.spoke2_to_hub_int_us_ilb4_nva_routes_tagged
  provider     = google-beta
  project      = var.project_id_spoke2
  name         = each.key
  dest_range   = each.value.dest
  network      = google_compute_network.spoke2_vpc.self_link
  next_hop_ilb = module.hub_int_us_ilb4_nva.forwarding_rule_address
  tags         = try(each.value.tags, null)
  priority     = each.value.priority
}
