
####################################################
# gke cluster
####################################################

# cluster

resource "google_container_cluster" "hub_cluster" {
  project  = var.project_id_hub
  name     = "${local.hub_prefix}cluster"
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
      for_each = local.hub_master_authorized_networks
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

  # lifecycle {
  #   ignore_changes = all
  # }
}

data "google_container_cluster" "hub_cluster" {
  project  = var.project_id_hub
  name     = google_container_cluster.hub_cluster.name
  location = google_container_cluster.hub_cluster.location
}

# node pool
#------------------------------------------

resource "google_container_node_pool" "hub_cluster" {
  project    = var.project_id_hub
  name       = "${local.hub_prefix}cluster"
  cluster    = google_container_cluster.hub_cluster.id
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
}

####################################################
# workload identity
####################################################

# kubernetes provider

provider "kubernetes" {
  alias                  = "hub"
  host                   = "https://${data.google_container_cluster.hub_cluster.endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.hub_cluster.master_auth.0.cluster_ca_certificate)
}

# gcp service account

module "hub_sa_gke" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v34.1.0"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}sa-gke"
  # iam = {
  #   "roles/iam.workloadIdentityUser" = [
  #     "serviceAccount:${var.project_id_hub}.svc.id.goog[${local.hub_cluster_namespace}/${local.hub_prefix}sa-gke]"
  #   ]
  # }
  iam_project_roles = {
    "${var.project_id_hub}" = [
      "roles/editor",
    ]
  }
}

# # k8s service account

# resource "kubernetes_service_account" "hub_sa_gke" {
#   provider = kubernetes.hub
#   metadata {
#     name      = "cluster-ksa"
#     namespace = local.hub_cluster_namespace
#     annotations = {
#       "iam.gke.io/gcp-service-account" = module.hub_sa_gke.email
#     }
#   }
# }

# iam policy binding

# resource "google_project_iam_member" "hub_cluster_workload_id_role" {
#   service_account_id = module.hub_sa_gke.id
#   role               = "roles/iam.workloadIdentityUser"
#   member             = "serviceAccount:${var.project_id_hub}.svc.id.goog[${local.hub_cluster_namespace}/${local.hub_prefix}sa-gke]"
# }
