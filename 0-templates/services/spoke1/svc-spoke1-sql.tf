
# eu instance

locals {
  authorized_networks_internal = local.netblocks.internal
}

resource "google_sql_database_instance" "spoke1_eu_cloudsql" {
  provider = google-beta
  project  = var.project_id_spoke1
  name     = local.spoke1_eu_cloudsql_name
  region   = local.spoke1_eu_region

  deletion_protection = false
  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.spoke1_vpc.self_link

      dynamic "authorized_networks" {
        for_each = local.authorized_networks_internal
        iterator = internal
        content {
          name  = "internal-${internal.key}"
          value = internal.value
        }
      }
    }
  }
  depends_on = [google_service_networking_connection.spoke1]
}

resource "google_sql_user" "spoke1_eu_sql_users" {
  for_each = local.spoke1_cloudsql_users
  project  = var.project_id_spoke1
  name     = each.key
  host     = each.value.host
  password = each.value.password
  instance = google_sql_database_instance.spoke1_eu_cloudsql.name
}

locals {
  spoke1_eu_cloud_sql_proxy = templatefile("../scripts/startup/proxy_sql.sh", {
    WEB_PORT = local.web_svc.port
    # cloud_sql_proxy with dnat to 127.0.0.1
    PROJECT_SQL = var.project_id_spoke1
    REGION      = local.spoke1_eu_region
    INSTANCE    = local.spoke1_eu_cloudsql_name
    SQL_IP      = "127.0.0.1"
    PORT        = 3306
    USER        = "admin"
    PASSWORD    = local.spoke1_cloudsql_users.admin.password
    # scripts to access sql db
    SQL_ACCESS_VIA_LOCAL_HOST = local.sql_access_via_local_host
    SQL_ACCESS_VIA_PROXY      = local.sql_access_via_proxy
  })
}

module "spoke1_eu_cloud_sql_proxy" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/compute-vm"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}eu-cloud-sql-proxy"
  region     = local.spoke1_eu_region
  network_interfaces = [
    {
      network    = google_compute_network.spoke1_vpc.self_link
      subnetwork = local.spoke1_eu_subnet1.self_link
      alias_ips  = null
      nat        = false
      addresses = {
        internal = [local.spoke1_eu_sql_proxy_addr]
        external = null
      }
    }
  ]
  metadata = {
    startup-script = local.spoke1_eu_cloud_sql_proxy
  }
  service_account_scopes = ["cloud-platform"]
}
