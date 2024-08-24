
# cluster eu

module "spoke1_eu_clust1" {
  source                    = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-cluster"
  project_id                = var.project_id_spoke1
  name                      = "${local.spoke1_prefix}eu-clust1"
  location                  = local.spoke1_eu_region
  network                   = google_compute_network.spoke1_vpc.self_link
  subnetwork                = local.spoke1_eu_subnet2.self_link
  secondary_range_pods      = "pods"
  secondary_range_services  = "services"
  default_max_pods_per_node = 110
  master_authorized_ranges = {
    internal-vms = "10.0.0.0/8"
    external     = "0.0.0.0/0"
  }
  private_cluster_config = {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = local.spoke1_gke_master_cidr1
    master_global_access    = true
  }
  addons = {
    cloudrun_config            = true
    dns_cache_config           = true
    horizontal_pod_autoscaling = true
    http_load_balancing        = true
    istio_config = {
      enabled = true
      tls     = false
    }
    network_policy_config                 = true
    gce_persistent_disk_csi_driver_config = false
  }
  labels = {
    environment = "dev"
  }
}

module "spoke1_eu_clust1_nodepool" {
  source                   = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-nodepool"
  project_id               = var.project_id_spoke1
  cluster_name             = module.spoke1_eu_clust1.name
  location                 = local.spoke1_eu_region
  node_locations           = ["${local.spoke1_eu_region}-b", "${local.spoke1_eu_region}-c"]
  name                     = "${local.spoke1_prefix}eu-clust1-nodepool"
  initial_node_count       = 1
  node_machine_type        = "e2-standard-4"
  node_service_account     = module.spoke1_sa.email
  workload_metadata_config = "EXPOSE"
}

locals {
  spoke1_gke_flasky_gcr_host = "gcr.io"
}

resource "template_dir" "spoke1_eu_clust_config" {
  source_dir      = "../../templates/gke/flasky"
  destination_dir = "rendered/gke/eu-clust1/flasky"
  vars = {
    PROJECT_ID  = var.project_id_spoke1
    CLUSTER     = "${local.spoke1_prefix}eu-clust1"
    REGION      = local.spoke1_eu_region
    GCR_HOST    = local.spoke1_gke_flasky_gcr_host
    IMAGE_REPO  = "${local.spoke1_gke_flasky_gcr_host}/${var.project_id_spoke1}/gke-flasky:v1"
    NAMESPACE   = "flasky"
    APP_NAME    = "flasky"
    PORT        = "80"
    TARGET_PORT = "8080"
  }
}
