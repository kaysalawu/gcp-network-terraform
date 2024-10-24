
# cluster us
#---------------------------------

data "google_container_engine_versions" "spoke2_us_region" {
  project        = var.project_id_spoke2
  provider       = google-beta
  location       = local.spoke2_us_region
  version_prefix = "1.20.9"
}

/*
output "test" {
  value = data.google_container_engine_versions.spoke2_us_region.valid_master_versions
}*/

module "spoke2_us_clust1" {
  source                   = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-cluster"
  project_id               = var.project_id_spoke2
  name                     = "${local.spoke2_prefix}us-clust1"
  location                 = local.spoke2_us_region
  node_locations           = ["${local.spoke2_us_region}-b", "${local.spoke2_us_region}-c"]
  network                  = google_compute_network.spoke2_vpc.self_link
  subnetwork               = local.spoke2_us_subnet2.self_link
  secondary_range_pods     = "pods"
  secondary_range_services = "services"
  #min_master_version          = "1.20.9-gke.1000"
  enable_intranode_visibility = true
  release_channel             = "STABLE"
  default_max_pods_per_node   = 110
  master_authorized_ranges = {
    internal-vms = "10.0.0.0/8"
    external     = "0.0.0.0/0"
  }
  private_cluster_config = {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = local.spoke2_gke_master_cidr1
    master_global_access    = true
  }
  addons = {
    cloudrun_config            = true
    dns_cache_config           = true
    horizontal_pod_autoscaling = true
    http_load_balancing        = true
    istio_config = {
      enabled = false
      tls     = false
    }
    network_policy_config                 = true
    gce_persistent_disk_csi_driver_config = false
  }
  labels = {
    environment = "spoke2-us"
  }
}

module "spoke2_us_clust1_nodepool" {
  source                   = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-nodepool"
  project_id               = var.project_id_spoke2
  cluster_name             = module.spoke2_us_clust1.name
  location                 = local.spoke2_us_region
  node_locations           = ["${local.spoke2_us_region}-b", "${local.spoke2_us_region}-c"]
  name                     = "${local.spoke2_prefix}us-clust1-nodepool"
  initial_node_count       = 1
  node_machine_type        = "e2-standard-4"
  node_service_account     = module.spoke2_sa.email
  workload_metadata_config = "GCE_METADATA"
  node_tags                = [local.tag_ssh, local.tag_gfe]
}

# flasky app
#---------------------------------

data "google_project" "spoke2_project" {
  project_id = var.project_id_spoke2
}

locals {
  spoke2_gke_flasky_gcr_host = "gcr.io"
}

resource "template_dir" "spoke2_us_clust_config_flasky" {
  source_dir      = "../../templates/gke/flasky"
  destination_dir = "rendered/gke/us-clust1/flasky"
  vars = {
    PROJECT_ID = var.project_id_spoke2
    CLUSTER    = "${local.spoke2_prefix}us-clust1"
    REGION     = local.spoke2_us_region
    GCR_HOST   = local.spoke2_gke_flasky_gcr_host
    IMAGE_REPO = "${local.spoke2_gke_flasky_gcr_host}/${var.project_id_spoke2}/gke-flasky:v3"
    # flasky
    NEG_NAME     = "${local.spoke2_prefix}us-gke-neg"
    SERVICE_NAME = "${local.spoke2_prefix}us-gke-svc"
    NAMESPACE    = "flasky"
    APP_NAME     = "flasky"
    PORT         = 80
    TARGET_PORT  = local.svc_web.port
  }
}

# api proxy
#---------------------------------

locals {
  spoke2_us_privoxy_host = "gcr.io"
}

resource "template_dir" "spoke2_us_clust_config_privoxy" {
  source_dir      = "../../templates/gke/privoxy"
  destination_dir = "rendered/gke/us-clust1/privoxy"
  vars = {
    PROJECT_ID = var.project_id_spoke2
    CLUSTER    = "${local.spoke2_prefix}us-clust1"
    REGION     = local.spoke2_us_region
    GCR_HOST   = local.spoke2_gke_flasky_gcr_host
    IMAGE_REPO = "${local.spoke2_gke_flasky_gcr_host}/${var.project_id_spoke2}/k8s-api-proxy:0.1"

  }
}

# ingress app
#---------------------------------

resource "google_compute_global_address" "spoke2_gke_ingress_addr" {
  project = var.project_id_spoke2
  name    = "${local.spoke2_prefix}gke-ingress-addr"
}

locals {
  spoke2_gke_ingress_gcr_host = "gcr.io"
  spoke2_gke_ingress_app_host = "gke-us.${data.google_dns_managed_zone.public_zone.dns_name}"
  spoke2_gke_ingress_domains  = [local.spoke2_gke_ingress_app_host, ]
}

resource "template_dir" "spoke2_gke_ingress_config" {
  source_dir      = "../../templates/gke/ingress"
  destination_dir = "rendered/gke/us-clust1/ingress"
  vars = {
    PROJECT_ID = var.project_id_spoke2
    CLUSTER    = "${local.spoke2_prefix}us-clust1"
    REGION     = local.spoke2_us_region
    GCR_HOST   = local.spoke2_gke_ingress_gcr_host
    IMAGE_REPO = "${local.spoke2_gke_ingress_gcr_host}/${var.project_id_spoke2}/gke-ingress:v3"

    NEG_NAME     = "${local.spoke2_prefix}us-gke-neg"
    SERVICE_NAME = "${local.spoke2_prefix}us-gke-svc"
    NAMESPACE    = "ingress"
    APP_NAME     = trimsuffix("${local.spoke2_prefix}", "-")
    PORT         = 80
    TARGET_PORT  = local.svc_web.port
    HOST1        = trimsuffix("gke-us.${data.google_dns_managed_zone.public_zone.dns_name}", ".")
    GCLB_ADDR    = "${local.spoke2_prefix}gke-ingress-addr"
  }
}

resource "google_dns_record_set" "spoke2_gke_ingress_dns" {
  for_each     = toset(local.spoke2_gke_ingress_domains)
  project      = var.project_id_hub
  managed_zone = data.google_dns_managed_zone.public_zone.name
  name         = each.value
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.spoke2_gke_ingress_addr.address]
}
