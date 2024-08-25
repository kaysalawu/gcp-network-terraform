
# https://cloud.google.com/traffic-director/docs/set-up-gce-vms-auto
# https://cloud.google.com/traffic-director/tutorials/network-edge-services-multi-environment
# https://cloud.google.com/traffic-director/tutorials/network-edge-services-multi-environment#load-balancing-components

# health checks
#--------------------------------------------

# grpc-cloud

resource "google_compute_health_check" "hub_td_grpc_cloud_hc" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}td-grpc-cloud-hc"
  grpc_health_check {
    port_specification = "USE_SERVING_PORT"
  }
}

# envoy-cloud

resource "google_compute_health_check" "hub_td_envoy_cloud_hc" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}td-envoy-cloud-hc"
  http_health_check {
    port_specification = "USE_SERVING_PORT"
  }
}

# envoy-hybrid

resource "google_compute_health_check" "hub_td_envoy_hybrid_hc" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}td-envoy-hybrid-hc"
  http_health_check {
    port = local.svc_web.port # named port not supported on negs
  }
}

# instances
#--------------------------------------------

# grpc-cloud

locals {
  hub_td_grpc_cloud_vm_startup = templatefile("../../scripts/startup/server-grpc.sh", {})
}

resource "google_compute_instance" "hub_eu_td_grpc_cloud_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-td-grpc-cloud"
  zone         = "${local.hub_eu_region}-b"
  machine_type = "e2-medium"
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    subnetwork = local.hub_eu_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.hub_td_grpc_cloud_vm_startup
}

resource "google_compute_instance" "hub_us_td_grpc_cloud_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}us-td-grpc-cloud"
  zone         = "${local.hub_us_region}-b"
  machine_type = "e2-medium"
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    subnetwork = local.hub_us_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.hub_td_grpc_cloud_vm_startup
}

# envoy-cloud

locals {
  hub_td_envoy_cloud_vm_startup = templatefile("../../scripts/startup/server-web.sh", { PORT = local.svc_web.port })
}

resource "google_compute_instance" "hub_eu_td_envoy_cloud_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-td-envoy-cloud"
  zone         = "${local.hub_eu_region}-b"
  machine_type = "e2-micro"
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.hub_td_envoy_cloud_vm_startup
}

resource "google_compute_instance" "hub_us_td_envoy_cloud_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}us-td-envoy-cloud"
  zone         = "${local.hub_us_region}-b"
  machine_type = "e2-micro"
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.hub_td_envoy_cloud_vm_startup
}

# groups
#--------------------------------------------

# grpc-cloud ig

resource "google_compute_instance_group" "hub_eu_td_grpc_cloud_ig" {
  project   = var.project_id_hub
  name      = "${local.hub_prefix}eu-td-grpc-cloud-ig"
  zone      = "${local.hub_eu_region}-b"
  instances = [google_compute_instance.hub_eu_td_grpc_cloud_vm.self_link]
  named_port {
    name = local.svc_grpc.name
    port = local.svc_grpc.port
  }
}

resource "google_compute_instance_group" "hub_us_td_grpc_cloud_ig" {
  project   = var.project_id_hub
  name      = "${local.hub_prefix}us-td-grpc-cloud-ig"
  zone      = "${local.hub_us_region}-b"
  instances = [google_compute_instance.hub_us_td_grpc_cloud_vm.self_link]
  named_port {
    name = local.svc_grpc.name
    port = local.svc_grpc.port
  }
}

# envoy-cloud ig

resource "google_compute_instance_group" "hub_us_td_envoy_cloud_ig" {
  project   = var.project_id_hub
  name      = "${local.hub_prefix}us-td-envoy-cloud-ig"
  zone      = "${local.hub_us_region}-b"
  instances = [google_compute_instance.hub_us_td_envoy_cloud_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

resource "google_compute_instance_group" "hub_eu_td_envoy_cloud_ig" {
  project   = var.project_id_hub
  name      = "${local.hub_prefix}eu-td-envoy-cloud-ig"
  zone      = "${local.hub_eu_region}-b"
  instances = [google_compute_instance.hub_eu_td_envoy_cloud_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# envoy-hybrid neg

locals {
  hub_eu_td_envoy_hybrid_neg_create = templatefile("../../scripts/neg/hybrid/create.sh", {
    PROJECT_ID  = var.project_id_hub
    NETWORK     = google_compute_network.hub_vpc.name
    SUBNET      = local.hub_eu_subnet1.name
    NEG_NAME    = "${local.hub_prefix}eu-td-cloud-hybrid-neg"
    ZONE        = "${local.hub_eu_region}-c"
    NE_TYPE     = "non-gcp-private-ip-port"
    REMOTE_IP   = local.site1_vm_addr
    REMOTE_PORT = local.svc_web.port
  })
  hub_eu_td_envoy_hybrid_neg_delete = templatefile("../../scripts/neg/hybrid/delete.sh", {
    PROJECT_ID = var.project_id_hub
    NEG_NAME   = "${local.hub_prefix}eu-td-cloud-hybrid-neg"
    ZONE       = "${local.hub_eu_region}-c"
  })
}

locals {
  hub_us_td_envoy_hybrid_neg_create = templatefile("../../scripts/neg/hybrid/create.sh", {
    PROJECT_ID  = var.project_id_hub
    NETWORK     = google_compute_network.hub_vpc.name
    SUBNET      = local.hub_us_subnet1.name
    NEG_NAME    = "${local.hub_prefix}us-td-cloud-hybrid-neg"
    ZONE        = "${local.hub_us_region}-c"
    NE_TYPE     = "non-gcp-private-ip-port"
    REMOTE_IP   = local.site2_vm_addr
    REMOTE_PORT = local.svc_web.port
  })
  hub_us_td_envoy_hybrid_neg_delete = templatefile("../../scripts/neg/hybrid/delete.sh", {
    PROJECT_ID = var.project_id_hub
    NEG_NAME   = "${local.hub_prefix}us-td-cloud-hybrid-neg"
    ZONE       = "${local.hub_us_region}-c"
  })
}

resource "null_resource" "hub_eu_td_envoy_hybrid_neg" {
  triggers = {
    create = local.hub_eu_td_envoy_hybrid_neg_create
    delete = local.hub_eu_td_envoy_hybrid_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

resource "null_resource" "hub_us_td_envoy_hybrid_neg" {
  triggers = {
    create = local.hub_us_td_envoy_hybrid_neg_create
    delete = local.hub_us_td_envoy_hybrid_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

data "google_compute_network_endpoint_group" "hub_eu_td_envoy_hybrid_neg" {
  depends_on = [null_resource.hub_eu_td_envoy_hybrid_neg]
  project    = var.project_id_hub
  name       = "${local.hub_prefix}eu-td-cloud-hybrid-neg"
  zone       = "${local.hub_eu_region}-c"
}

data "google_compute_network_endpoint_group" "hub_us_td_envoy_hybrid_neg" {
  depends_on = [null_resource.hub_us_td_envoy_hybrid_neg]
  project    = var.project_id_hub
  name       = "${local.hub_prefix}us-td-cloud-hybrid-neg"
  zone       = "${local.hub_us_region}-c"
}

# backend services
#--------------------------------------------

# grpc-cloud

resource "google_compute_backend_service" "hub_td_grpc_cloud_be_svc" {
  provider  = google-beta
  project   = var.project_id_hub
  name      = "${local.hub_prefix}td-grpc-cloud-be-svc"
  port_name = local.svc_grpc.name
  protocol  = "GRPC"
  backend {
    group = google_compute_instance_group.hub_eu_td_grpc_cloud_ig.id
  }
  backend {
    group = google_compute_instance_group.hub_us_td_grpc_cloud_ig.id
  }
  health_checks         = [google_compute_health_check.hub_td_grpc_cloud_hc.self_link]
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
}

# envoy-cloud

resource "google_compute_backend_service" "hub_td_envoy_cloud_be_svc" {
  provider  = google-beta
  project   = var.project_id_hub
  name      = "${local.hub_prefix}td-envoy-cloud-be-svc"
  port_name = local.svc_web.name
  protocol  = "HTTP"
  backend {
    group = google_compute_instance_group.hub_eu_td_envoy_cloud_ig.id
  }
  backend {
    group = google_compute_instance_group.hub_us_td_envoy_cloud_ig.id
  }
  health_checks         = [google_compute_health_check.hub_td_envoy_cloud_hc.self_link]
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
}

# envoy-hybrid

resource "google_compute_backend_service" "hub_td_envoy_hybrid_be_svc" {
  provider = google-beta
  project  = var.project_id_hub
  name     = "${local.hub_prefix}td-envoy-hybrid-be-svc"
  protocol = "HTTP"
  backend {
    group                 = data.google_compute_network_endpoint_group.hub_eu_td_envoy_hybrid_neg.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 5
  }
  backend {
    group                 = data.google_compute_network_endpoint_group.hub_us_td_envoy_hybrid_neg.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 5
  }
  health_checks         = [google_compute_health_check.hub_td_envoy_hybrid_hc.self_link]
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
}

# traffic director url map
#--------------------------------------------

# grpc-cloud

resource "google_compute_url_map" "hub_td_grpc_cloud_url_map" {
  provider = google-beta
  project  = var.project_id_hub
  name     = "${local.hub_prefix}td-grpc-cloud-url-map"
  host_rule {
    path_matcher = "grpc"
    hosts        = ["${local.hub_td_grpc_cloud_svc}.${local.hub_td_domain}", ]
  }
  path_matcher {
    name            = "grpc"
    default_service = google_compute_backend_service.hub_td_grpc_cloud_be_svc.self_link
  }
  default_service = google_compute_backend_service.hub_td_grpc_cloud_be_svc.self_link
}

# envoy-cloud

resource "google_compute_url_map" "hub_td_envoy_cloud_url_map" {
  provider = google-beta
  project  = var.project_id_hub
  name     = "${local.hub_prefix}td-envoy-cloud-url-map"
  host_rule {
    path_matcher = "envoy-cloud-svc"
    hosts        = ["${local.hub_td_envoy_cloud_svc}.${local.hub_td_domain}", ]
  }
  path_matcher {
    name            = "envoy-cloud-svc"
    default_service = google_compute_backend_service.hub_td_envoy_cloud_be_svc.self_link
  }
  default_service = google_compute_backend_service.hub_td_envoy_cloud_be_svc.self_link
}

# envoy-hybrid

resource "google_compute_url_map" "hub_td_envoy_hybrid_url_map" {
  provider = google-beta
  project  = var.project_id_hub
  name     = "${local.hub_prefix}td-envoy-hybrid-url-map"
  host_rule {
    path_matcher = "envoy-hybrid-svc"
    hosts        = ["${local.hub_td_envoy_hybrid_svc}.${local.hub_td_domain}", ]
  }
  path_matcher {
    name            = "envoy-hybrid-svc"
    default_service = google_compute_backend_service.hub_td_envoy_hybrid_be_svc.self_link
  }
  default_service = google_compute_backend_service.hub_td_envoy_hybrid_be_svc.self_link
}

# target proxies
#--------------------------------------------

# grpc-cloud

resource "google_compute_target_grpc_proxy" "hub_td_grpc_cloud_proxy" {
  project                = var.project_id_hub
  name                   = "${local.hub_prefix}td-grpc-cloud-proxy"
  url_map                = google_compute_url_map.hub_td_grpc_cloud_url_map.self_link
  validate_for_proxyless = true
}

# envoy-cloud

resource "google_compute_target_http_proxy" "hub_td_envoy_cloud_proxy" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}td-envoy-cloud-proxy"
  url_map = google_compute_url_map.hub_td_envoy_cloud_url_map.self_link
}

# envoy-hybrid

resource "google_compute_target_http_proxy" "hub_td_envoy_hybrid_proxy" {
  provider   = google-beta
  project    = var.project_id_hub
  name       = "${local.hub_prefix}td-envoy-hybrid-proxy"
  url_map    = google_compute_url_map.hub_td_envoy_hybrid_url_map.self_link
  proxy_bind = true
}

# forwarding rules
#--------------------------------------------

# grpc-cloud

resource "google_compute_global_forwarding_rule" "hub_td_grpc_cloud_fr" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = "${local.hub_prefix}td-grpc-cloud-fr"
  target                = google_compute_target_grpc_proxy.hub_td_grpc_cloud_proxy.self_link
  network               = google_compute_network.hub_vpc.self_link
  ip_address            = "0.0.0.0" # required for grpc proxyless
  port_range            = "80"
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
}

# envoy-cloud

resource "google_compute_global_forwarding_rule" "hub_td_envoy_cloud_fr" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = "${local.hub_prefix}td-envoy-cloud-fr"
  target                = google_compute_target_http_proxy.hub_td_envoy_cloud_proxy.self_link
  network               = google_compute_network.hub_vpc.self_link
  ip_address            = local.hub_td_envoy_cloud_addr # can use specific vip for standard envoy
  port_range            = local.svc_web.port
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
}

# envoy-hybrid

resource "google_compute_global_forwarding_rule" "hub_td_envoy_hybrid_fr" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = "${local.hub_prefix}td-envoy-hybrid-fr"
  target                = google_compute_target_http_proxy.hub_td_envoy_hybrid_proxy.self_link
  network               = google_compute_network.hub_vpc.self_link
  ip_address            = "0.0.0.0" # required for proxyBind
  port_range            = local.svc_web.port
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
}

# service directory
#--------------------------------------------

# envoy-cloud

resource "google_service_directory_service" "hub_td_envoy_cloud" {
  provider   = google-beta
  service_id = local.hub_td_envoy_cloud_svc
  namespace  = google_service_directory_namespace.hub_td.id
  metadata = {
    service = local.hub_td_envoy_cloud_svc
    region  = local.hub_us_region
  }
}

resource "google_service_directory_endpoint" "hub_td_envoy_cloud_fr" {
  provider    = google-beta
  endpoint_id = "default"
  service     = google_service_directory_service.hub_td_envoy_cloud.id
  address     = google_compute_global_forwarding_rule.hub_td_envoy_cloud_fr.ip_address
  port        = local.svc_web.port
  metadata = {
    service = local.hub_td_envoy_cloud_svc
    region  = local.hub_us_region
  }
}

# envoy-hybrid

resource "google_service_directory_service" "hub_td_envoy_hybrid" {
  provider   = google-beta
  service_id = local.hub_td_envoy_hybrid_svc
  namespace  = google_service_directory_namespace.hub_td.id
  metadata = {
    service = local.hub_td_envoy_hybrid_svc
    region  = local.hub_us_region
  }
}

resource "google_service_directory_endpoint" "hub_td_envoy_hybrid_fr" {
  provider    = google-beta
  endpoint_id = "default"
  service     = google_service_directory_service.hub_td_envoy_hybrid.id
  address     = google_compute_global_forwarding_rule.hub_td_envoy_hybrid_fr.ip_address
  port        = local.svc_web.port
  metadata = {
    service = local.hub_td_envoy_hybrid_svc
    region  = local.hub_us_region
  }
}

# envoy bridge
#---------------------------------

locals {
  hub_eu_td_envoy_bridge_tpl_create = templatefile("../../scripts/envoy/tpl-create.sh", {
    PROJECT_ID    = var.project_id_hub
    TEMPLATE_NAME = "${local.hub_prefix}eu-td-envoy-bridge-tpl"
    NETWORK_NAME  = google_compute_network.hub_vpc.name
    REGION        = local.hub_eu_region
    SUBNET_NAME   = local.hub_eu_subnet1.name
    METADATA      = ""
  })
  hub_eu_td_envoy_bridge_tpl_delete = templatefile("../../scripts/envoy/tpl-delete.sh", {
    PROJECT_ID    = var.project_id_hub
    TEMPLATE_NAME = "${local.hub_prefix}eu-td-envoy-bridge-tpl"
  })
}

locals {
  hub_us_td_envoy_bridge_tpl_create = templatefile("../../scripts/envoy/tpl-create.sh", {
    PROJECT_ID    = var.project_id_hub
    TEMPLATE_NAME = "${local.hub_prefix}us-td-envoy-bridge-tpl"
    NETWORK_NAME  = google_compute_network.hub_vpc.name
    REGION        = local.hub_us_region
    SUBNET_NAME   = local.hub_us_subnet1.name
    METADATA      = ""
  })
  hub_us_td_envoy_bridge_tpl_delete = templatefile("../../scripts/envoy/tpl-delete.sh", {
    PROJECT_ID    = var.project_id_hub
    TEMPLATE_NAME = "${local.hub_prefix}us-td-envoy-bridge-tpl"
  })
}

# instance template

resource "null_resource" "hub_eu_td_envoy_bridge_tpl" {
  triggers = {
    create = local.hub_eu_td_envoy_bridge_tpl_create
    delete = local.hub_eu_td_envoy_bridge_tpl_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

resource "null_resource" "hub_us_td_envoy_bridge_tpl" {
  triggers = {
    create = local.hub_us_td_envoy_bridge_tpl_create
    delete = local.hub_us_td_envoy_bridge_tpl_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

data "google_compute_instance_template" "hub_eu_td_envoy_bridge_tpl" {
  depends_on = [null_resource.hub_eu_td_envoy_bridge_tpl]
  project    = var.project_id_hub
  name       = "${local.hub_prefix}eu-td-envoy-bridge-tpl"
}

data "google_compute_instance_template" "hub_us_td_envoy_bridge_tpl" {
  depends_on = [null_resource.hub_us_td_envoy_bridge_tpl]
  project    = var.project_id_hub
  name       = "${local.hub_prefix}us-td-envoy-bridge-tpl"
}

# instance

resource "google_compute_instance_from_template" "hub_eu_td_envoy_bridge_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-td-envoy-bridge"
  zone         = "${local.hub_eu_region}-b"
  machine_type = "e2-medium"
  tags         = [local.tag_ssh, local.tag_gfe]
  network_interface {
    subnetwork = local.hub_eu_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  source_instance_template = data.google_compute_instance_template.hub_us_td_envoy_bridge_tpl.name
}

resource "google_compute_instance_from_template" "hub_us_td_envoy_bridge_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}us-td-envoy-bridge"
  zone         = "${local.hub_us_region}-b"
  machine_type = "e2-medium"
  tags         = [local.tag_ssh, local.tag_gfe]
  network_interface {
    subnetwork = local.hub_us_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  source_instance_template = data.google_compute_instance_template.hub_us_td_envoy_bridge_tpl.name
}

# instance groups

resource "google_compute_instance_group" "hub_eu_td_envoy_bridge_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_eu_region}-b"
  name      = "${local.hub_prefix}eu-td-envoy-bridge-ig"
  instances = [google_compute_instance_from_template.hub_eu_td_envoy_bridge_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

resource "google_compute_instance_group" "hub_us_td_envoy_bridge_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_us_region}-b"
  name      = "${local.hub_prefix}us-td-envoy-bridge-ig"
  instances = [google_compute_instance_from_template.hub_us_td_envoy_bridge_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# ilb4

module "hub_us_td_envoy_bridge_ilb" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb?ref=v15.0.0"
  project_id    = var.project_id_hub
  region        = local.hub_us_region
  name          = google_compute_instance_from_template.hub_us_td_envoy_bridge_vm.name
  service_label = "${local.hub_prefix}us-td-envoy-bridge-ilb"
  network       = google_compute_network.hub_vpc.self_link
  subnetwork    = local.hub_us_subnet1.self_link
  address       = local.hub_us_td_envoy_bridge_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.hub_us_td_envoy_bridge_ig.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type    = "http"
    config  = {}
    logging = true
    check = {
      port_specification = "USE_FIXED_PORT"
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
    }
  }
  global_access = true
}

module "hub_eu_td_envoy_bridge_ilb" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb?ref=v15.0.0"
  project_id    = var.project_id_hub
  region        = local.hub_eu_region
  name          = google_compute_instance_from_template.hub_eu_td_envoy_bridge_vm.name
  service_label = "${local.hub_prefix}eu-td-envoy-bridge-ilb"
  network       = google_compute_network.hub_vpc.self_link
  subnetwork    = local.hub_eu_subnet1.self_link
  address       = local.hub_eu_td_envoy_bridge_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.hub_eu_td_envoy_bridge_ig.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type    = "http"
    config  = {}
    logging = true
    check = {
      port_specification = "USE_FIXED_PORT"
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
    }
  }
  global_access = true
}

# test client
#---------------------------------

locals {
  hub_eu_td_client_tpl_create = templatefile("../../scripts/envoy/tpl-create.sh", {
    PROJECT_ID    = var.project_id_hub
    TEMPLATE_NAME = "${local.hub_prefix}eu-td-client-tpl"
    NETWORK_NAME  = google_compute_network.hub_vpc.name
    REGION        = local.hub_eu_region
    SUBNET_NAME   = local.hub_eu_subnet1.name
    METADATA      = local.td_client_startup
  })
  hub_eu_td_client_tpl_delete = templatefile("../../scripts/envoy/tpl-delete.sh", {
    PROJECT_ID    = var.project_id_hub
    TEMPLATE_NAME = "${local.hub_prefix}eu-td-client-tpl"
  })
}

locals {
  hub_us_td_client_tpl_create = templatefile("../../scripts/envoy/tpl-create.sh", {
    PROJECT_ID    = var.project_id_hub
    TEMPLATE_NAME = "${local.hub_prefix}us-td-client-tpl"
    NETWORK_NAME  = google_compute_network.hub_vpc.name
    REGION        = local.hub_us_region
    SUBNET_NAME   = local.hub_us_subnet1.name
    METADATA      = local.td_client_startup
  })
  hub_us_td_client_tpl_delete = templatefile("../../scripts/envoy/tpl-delete.sh", {
    PROJECT_ID    = var.project_id_hub
    TEMPLATE_NAME = "${local.hub_prefix}us-td-client-tpl"
  })
}

# instance templates

resource "null_resource" "hub_eu_td_client_tpl" {
  triggers = {
    create = local.hub_eu_td_client_tpl_create
    delete = local.hub_eu_td_client_tpl_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

resource "null_resource" "hub_us_td_client_tpl" {
  triggers = {
    create = local.hub_us_td_client_tpl_create
    delete = local.hub_us_td_client_tpl_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

data "google_compute_instance_template" "hub_eu_td_client_tpl" {
  depends_on = [null_resource.hub_eu_td_client_tpl]
  project    = var.project_id_hub
  name       = "${local.hub_prefix}eu-td-client-tpl"
}

data "google_compute_instance_template" "hub_us_td_client_tpl" {
  depends_on = [null_resource.hub_us_td_client_tpl]
  project    = var.project_id_hub
  name       = "${local.hub_prefix}us-td-client-tpl"
}

# instances

resource "google_compute_instance_from_template" "hub_eu_td_client" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-td-client"
  zone    = "${local.hub_eu_region}-b"
  tags    = [local.tag_ssh, local.tag_gfe]
  network_interface {
    subnetwork = local.hub_eu_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  source_instance_template = data.google_compute_instance_template.hub_eu_td_client_tpl.name
}

resource "google_compute_instance_from_template" "hub_us_td_client" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}us-td-client"
  zone    = "${local.hub_us_region}-b"
  tags    = [local.tag_ssh, local.tag_gfe]
  network_interface {
    subnetwork = local.hub_us_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  source_instance_template = data.google_compute_instance_template.hub_us_td_client_tpl.name
}
