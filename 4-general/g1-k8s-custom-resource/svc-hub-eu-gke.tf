
locals {
  hub_eu_master_authorized_networks = [
    { display_name = "100-64-10", cidr_block = "100.64.0.0/10" },
    { display_name = "all", cidr_block = "0.0.0.0/0" }
  ]
}

####################################################
# gke cluster
####################################################

# cluster

resource "google_container_cluster" "hub_eu_cluster" {
  project  = var.project_id_hub
  name     = "${local.hub_prefix}eu-cluster"
  location = "${local.hub_eu_region}-b"

  default_max_pods_per_node = 110
  remove_default_node_pool  = true
  initial_node_count        = 1

  network           = module.hub_vpc.self_link
  subnetwork        = module.hub_vpc.subnet_self_links["${local.hub_eu_region}/eu-gke"]
  datapath_provider = "LEGACY_DATAPATH"

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes   = true
    master_ipv4_cidr_block = local.hub_eu_gke_master_cidr1
    master_global_access_config {
      enabled = true
    }
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = local.hub_eu_master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  dns_config {
    cluster_dns        = "CLOUD_DNS"
    cluster_dns_scope  = "CLUSTER_SCOPE"
    cluster_dns_domain = "cluster.local"
  }

  # workload_identity_config {
  #   workload_pool = "${var.project_id_hub}.svc.id.goog"
  # }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      # "POD",
      # "DAEMONSET",
      # "DEPLOYMENT",
      # "WORKLOADS",
    ]
    managed_prometheus {
      enabled = false
    }
  }

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  deletion_protection = false

  lifecycle {
    ignore_changes = [
      node_config[0].resource_labels,
    ]
  }
}

data "google_container_cluster" "hub_eu_cluster" {
  project  = var.project_id_hub
  name     = google_container_cluster.hub_eu_cluster.name
  location = google_container_cluster.hub_eu_cluster.location
}

####################################################
# node pool
####################################################

resource "google_container_node_pool" "hub_eu_cluster" {
  project    = var.project_id_hub
  name       = "${local.hub_prefix}eu-cluster"
  cluster    = google_container_cluster.hub_eu_cluster.id
  location   = "${local.hub_eu_region}-b"
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 1
  }

  node_config {
    machine_type    = "e2-medium"
    disk_size_gb    = "80"
    disk_type       = "pd-ssd"
    preemptible     = true
    service_account = module.hub_sa.email
    oauth_scopes    = ["cloud-platform"]
    tags            = [local.tag_ssh, ]

    # workload_metadata_config {
    #   mode = "GKE_METADATA"
    # }
  }
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  lifecycle {
    ignore_changes = [
      node_config[0].resource_labels,
    ]
  }
}

####################################################
# service accounts
####################################################

# gcp service account

module "hub_sa_gke" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v34.1.0"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}sa-gke"
  iam_project_roles = {
    "${var.project_id_hub}" = [
      "roles/editor",
    ]
  }
}
