
# network
#---------------------------------

# resource "google_compute_network" "this" {
#   project      = var.project_id
#   name         = "${var.prefix}vpc"
#   routing_mode = var.vpc_config.routing_mode
#   mtu          = var.vpc_config.mtu

#   auto_create_subnetworks         = var.vpc_config.auto_create
#   delete_default_routes_on_create = false
# }

# subnets
#---------------------------------

# resource "google_compute_subnetwork" "this" {
#   for_each      = local.hub_subnets
#   provider      = google-beta
#   project       = var.project_id
#   name          = each.key
#   network       = google_compute_network.hub_vpc.id
#   region        = each.value.region
#   ip_cidr_range = each.value.ip_cidr_range
#   secondary_ip_range = each.value.secondary_ip_range == null ? [] : [
#     for name, range in each.value.secondary_ip_range :
#     { range_name = name, ip_cidr_range = range }
#   ]
#   purpose = each.value.purpose
#   role    = each.value.role
# }
