
# instances
#---------------------------------

# attack (onprem)

locals {
  site1_ids_attack_startup = templatefile("../scripts/startup/ids/attack.sh", {
    TARGET = local.hub_eu_ids_server_addr
  })
}

module "site1_ids_attack" {
  source     = "../modules/compute-vm"
  project_id = var.project_id_onprem
  name       = "${local.site1_prefix}ids-attack"
  zone       = "${local.site1_region}-b"
  tags       = [local.tag_ssh, ]
  network_interfaces = [{
    network    = google_compute_network.site1_vpc.self_link
    subnetwork = local.site1_subnet1.self_link
    addresses = {
      internal = local.site1_ids_attack_addr
      external = null
    }
    nat       = false
    alias_ips = null
  }]
  service_account         = module.site1_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.site1_ids_attack_startup
}

# server (hub)

locals {
  hub_eu_ids_server_startup = templatefile("../scripts/startup/ids/server.sh", {})
}

module "hub_eu_ids_server" {
  source     = "../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-ids-server"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_ssh, "mirror"]
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      internal = local.hub_eu_ids_server_addr
      external = null
    }
    nat       = false
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_eu_ids_server_startup
}

# endpoint
#---------------------------------

locals {
  hub_eu_ids_endpoint_create = templatefile("../scripts/ids/endpoint/create.sh", {
    PROJECT_ID    = var.project_id_hub
    NETWORK       = google_compute_network.hub_vpc.name
    REGION        = local.hub_eu_region
    ZONE          = "${local.hub_eu_region}-c"
    SUBNET        = local.hub_eu_subnet1.name
    ENDPOINT_NAME = "${local.hub_prefix}endpoint"
    SEVERITY      = "INFORMATIONAL"
  })
  hub_eu_ids_endpoint_delete = templatefile("../scripts/ids/endpoint/delete.sh", {
    PROJECT_ID    = var.project_id_hub
    REGION        = local.hub_eu_region
    ZONE          = "${local.hub_eu_region}-c"
    ENDPOINT_NAME = "${local.hub_prefix}endpoint"
  })
}

resource "null_resource" "hub_eu_ids_endpoint" {
  depends_on = [google_service_networking_connection.hub_eu_psa_ranges]
  triggers = {
    create = local.hub_eu_ids_endpoint_create
    delete = local.hub_eu_ids_endpoint_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# mirror
#---------------------------------

locals {
  hub_eu_ids_mirror_create = templatefile("../scripts/ids/mirror/create.sh", {
    PROJECT_ID    = var.project_id_hub
    NETWORK       = google_compute_network.hub_vpc.name
    REGION        = local.hub_eu_region
    ZONE          = "${local.hub_eu_region}-c"
    SUBNET        = local.hub_eu_subnet1.name
    ENDPOINT_NAME = "${local.hub_prefix}endpoint"
    MIRROR        = local.hub_eu_ids_mirror
  })
  hub_eu_ids_mirror_delete = templatefile("../scripts/ids/mirror/delete.sh", {
    PROJECT_ID    = var.project_id_hub
    REGION        = local.hub_eu_region
    ZONE          = "${local.hub_eu_region}-c"
    ENDPOINT_NAME = "${local.hub_prefix}endpoint"
    MIRROR        = local.hub_eu_ids_mirror
  })
  hub_eu_ids_mirror = {
    name     = "${local.hub_prefix}mirror"
    tags     = join(",", ["mirror"])
    protocol = "tcp"
  }
}

resource "null_resource" "hub_eu_ids_mirror" {
  depends_on = [
    null_resource.hub_eu_ids_endpoint,
    google_service_networking_connection.hub_eu_psa_ranges
  ]
  triggers = {
    create = local.hub_eu_ids_mirror_create
    delete = local.hub_eu_ids_mirror_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}
