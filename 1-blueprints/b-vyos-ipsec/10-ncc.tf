
locals {
  ncc_advertised_prefixes = ["${(local.supernet)}=supernet", ]
}

# routers
#------------------------------------

# eu

resource "google_compute_router" "hub_eu_ncc_cr" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-ncc-cr"
  network = google_compute_network.hub_vpc.self_link
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
  network = google_compute_network.hub_vpc.self_link
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

# bgp

locals {
  ncc_spoke1_bgp_create = templatefile("scripts/ncc/appliance/create.sh", {
    PROJECT_ID = var.project_id_hub
    NETWORK    = google_compute_network.hub_vpc.self_link
    REGION     = local.hub_eu_region
    SUBNET     = local.hub_eu_subnet1.self_link
    HUB_NAME   = "${local.hub_prefix}ncc-hub"

    SPOKE_CR_NAME = google_compute_router.hub_eu_ncc_cr.name
    SPOKE_CR_ASN  = local.hub_eu_ncc_cr_asn
    SPOKE_CR_IP_0 = local.hub_eu_ncc_cr_addr0
    SPOKE_CR_IP_1 = local.hub_eu_ncc_cr_addr1

    APPLIANCE_NAME      = google_compute_instance.hub_eu_router.name
    APPLIANCE_IP        = google_compute_instance.hub_eu_router.network_interface.0.network_ip
    APPLIANCE_ASN       = local.hub_eu_router_asn
    APPLIANCE_ZONE      = "${local.hub_eu_region}-b"
    APPLIANCE_SELF_LINK = google_compute_instance.hub_eu_router.self_link

    APPLIANCE_ADVERTISED_PREFIXES = join(",", local.ncc_advertised_prefixes)
    APPLIANCE_SESSION_0_METRIC    = 155
    APPLIANCE_SESSION_1_METRIC    = 155
  })
  ncc_spoke1_bgp_delete = templatefile("scripts/ncc/appliance/delete.sh", {
    PROJECT_ID = var.project_id_hub
    SPOKE_NAME = "${local.prefix}ncc-spoke1"
    REGION     = local.hub_eu_region
  })
}

resource "null_resource" "ncc_spoke1" {
  depends_on = [
    google_network_connectivity_spoke.ncc_spoke1,
    google_compute_instance.hub_eu_router,
    google_compute_router.hub_eu_ncc_cr
  ]
  triggers = {
    create = local.ncc_spoke1_bgp_create
    delete = local.ncc_spoke1_bgp_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

resource "local_file" "ncc_spoke1_bgp_create" {
  content  = local.ncc_spoke1_bgp_create
  filename = "_config/ncc/spoke1/create.sh"
}

resource "local_file" "ncc_spoke1_bgp_delete" {
  content  = local.ncc_spoke1_bgp_delete
  filename = "_config/ncc/spoke1/delete.sh"
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

# bgp

locals {
  ncc_spoke2_bgp_create = templatefile("scripts/ncc/appliance/create.sh", {
    PROJECT_ID = var.project_id_hub
    NETWORK    = google_compute_network.hub_vpc.self_link
    REGION     = local.hub_us_region
    SUBNET     = local.hub_us_subnet1.self_link
    HUB_NAME   = "${local.hub_prefix}ncc-hub"

    SPOKE_CR_NAME = google_compute_router.hub_us_ncc_cr.name
    SPOKE_CR_ASN  = local.hub_us_ncc_cr_asn
    SPOKE_CR_IP_0 = local.hub_us_ncc_cr_addr0
    SPOKE_CR_IP_1 = local.hub_us_ncc_cr_addr1

    APPLIANCE_NAME      = google_compute_instance.hub_us_router.name
    APPLIANCE_IP        = google_compute_instance.hub_us_router.network_interface.0.network_ip
    APPLIANCE_ASN       = local.hub_us_router_asn
    APPLIANCE_ZONE      = "${local.hub_us_region}-b"
    APPLIANCE_SELF_LINK = google_compute_instance.hub_us_router.self_link

    APPLIANCE_ADVERTISED_PREFIXES = join(",", local.ncc_advertised_prefixes)
    APPLIANCE_SESSION_0_METRIC    = 155
    APPLIANCE_SESSION_1_METRIC    = 155
  })
  ncc_spoke2_bgp_delete = templatefile("scripts/ncc/appliance/delete.sh", {
    PROJECT_ID = var.project_id_hub
    SPOKE_NAME = "${local.prefix}ncc-spoke2"
    REGION     = local.hub_us_region
  })
}

resource "null_resource" "ncc_spoke2" {
  depends_on = [
    google_network_connectivity_spoke.ncc_spoke2,
    google_compute_instance.hub_us_router,
    google_compute_router.hub_us_ncc_cr
  ]
  triggers = {
    create = local.ncc_spoke2_bgp_create
    delete = local.ncc_spoke2_bgp_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

resource "local_file" "ncc_spoke2_bgp_create" {
  content  = local.ncc_spoke2_bgp_create
  filename = "_config/ncc/spoke2/create.sh"
}

resource "local_file" "ncc_spoke2_bgp_delete" {
  content  = local.ncc_spoke2_bgp_delete
  filename = "_config/ncc/spoke2/delete.sh"
}
