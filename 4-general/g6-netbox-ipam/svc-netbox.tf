

locals {
  DNS_SUFFIX    = module.hub_dns_private_zone.zone.dns_name
  SERVICE_NAME  = "${local.hub_prefix}netbox"
  NET_BOX_IMAGE = "docker.io/netboxcommunity/netbox:v4.2-3.2.0"

  REDIS_INSTANCE = "${local.hub_prefix}netbox-cache"
  REDIS_VERSION  = "REDIS_6_X"

  secrets = {
    DB_PASSWORD          = "J5brHrAXFLQSif0K"
    REDIS_PASSWORD       = "H733Kdjndks81"
    REDIS_CACHE_PASSWORD = "t4Ph722qJ5QHeQ1qfu36"
    SUPERUSER_PASSWORD   = "t4Ph722qJ5QHeQ1qfu36"
    EMAIL_PASSWORD       = "changeme"
    SECRET_KEY           = "r(m)9nLGnz$(_q3N4z1k(EFsMCjjjzx08x9VhNVcfd%6RF#r!6DE@+V5Zk2X"
  }
  SECRET_ID      = "netbox-secrets"
  SECRET_FILE    = ".env-local"
  SECRET_VERSION = "latest"

  POSTGRES_INSTANCE = "${local.hub_prefix}netbox-db"
  POSTGRES_VERSION  = "POSTGRES_14"
  POSTGRES_TIER     = "db-f1-micro"
  POSTGRES_PORT     = 5432

  ALLOWED_HOSTS                        = "*"
  DB_HOST                              = "${local.POSTGRES_INSTANCE}.${local.DNS_SUFFIX}"
  DB_PORT                              = local.POSTGRES_PORT
  DB_NAME                              = "netbox"
  DB_USER                              = "netbox"
  REDIS_CACHE_DATABASE                 = 1
  REDIS_CACHE_HOST                     = "${local.REDIS_INSTANCE}.${local.DNS_SUFFIX}"
  REDIS_CACHE_INSECURE_SKIP_TLS_VERIFY = false
  REDIS_CACHE_SSL                      = false
  REDIS_DATABASE                       = 0
  REDIS_HOST                           = "${local.REDIS_INSTANCE}.${local.DNS_SUFFIX}"
  REDIS_INSECURE_SKIP_TLS_VERIFY       = false
  REDIS_SSL                            = false

  db_host    = google_sql_database_instance.hub_postgres_db.private_ip_address
  redis_host = google_redis_instance.hub_redis_cache.host
  redis_port = google_redis_instance.hub_redis_cache.port

  cloud_run_users_iam = { "roles/run.invoker" = [
    "allUsers",
    "group:gcp-network-admins@cloudtuple.com",
    ]
  }
}

####################################################
# secrets
####################################################

resource "google_secret_manager_secret" "hub_netbox_secrets" {
  for_each  = local.secrets
  project   = var.project_id_hub
  secret_id = each.key
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "hub_netbox_secrets" {
  for_each    = local.secrets
  secret      = google_secret_manager_secret.hub_netbox_secrets[each.key].name
  secret_data = each.value
}

####################################################
# database (postgres)
####################################################

# instance

resource "google_sql_database_instance" "hub_postgres_db" {
  project             = var.project_id_hub
  name                = local.POSTGRES_INSTANCE
  region              = local.hub_eu_region
  database_version    = local.POSTGRES_VERSION
  deletion_protection = false

  settings {
    tier = local.POSTGRES_TIER
    ip_configuration {
      ipv4_enabled    = false
      private_network = module.hub_vpc.self_link
    }
  }
  timeouts {
    create = "30m"
  }
}

# users

resource "google_sql_user" "hub_postgres_db_user" {
  project  = var.project_id_hub
  instance = google_sql_database_instance.hub_postgres_db.name
  name     = local.DB_USER
  password = local.secrets.DB_PASSWORD
}

# databse

resource "google_sql_database" "hub_postgres_database" {
  project  = var.project_id_hub
  name     = local.DB_NAME
  instance = google_sql_database_instance.hub_postgres_db.name
}


# dns

resource "google_dns_record_set" "hub_postgres_db" {
  project      = var.project_id_hub
  name         = local.DB_HOST
  managed_zone = module.hub_dns_private_zone.name
  type         = "A"
  ttl          = 300
  rrdatas      = [local.db_host, ]
}

####################################################
# cache (redis)
####################################################

resource "google_redis_instance" "hub_redis_cache" {
  project        = var.project_id_hub
  name           = local.REDIS_INSTANCE
  tier           = "STANDARD_HA"
  memory_size_gb = 1

  region                  = local.hub_eu_region
  location_id             = "${local.hub_eu_region}-b"
  alternative_location_id = "${local.hub_eu_region}-c"

  authorized_network = module.hub_vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
  auth_enabled       = true

  redis_version = local.REDIS_VERSION
  display_name  = local.REDIS_INSTANCE

  maintenance_policy {
    weekly_maintenance_window {
      day = "TUESDAY"
      start_time {
        hours   = 0
        minutes = 30
        seconds = 0
        nanos   = 0
      }
    }
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_dns_record_set" "hub_redis_cache" {
  project      = var.project_id_hub
  name         = local.REDIS_CACHE_HOST
  managed_zone = module.hub_dns_private_zone.name
  type         = "A"
  ttl          = 300
  rrdatas      = [local.redis_host, ]
}

####################################################
# cloud run
####################################################

# service account

module "hub_cloud_run_netbox_sa" {
  source     = "../../modules/iam-service-account"
  project_id = var.project_id_hub
  name       = "${local.SERVICE_NAME}-sa"
  iam_project_roles = {
    (var.project_id_hub) = ["roles/owner", ]
  }
}

resource "google_secret_manager_secret_iam_member" "hub_netbox_secrets_iam" {
  for_each  = google_secret_manager_secret.hub_netbox_secrets
  project   = var.project_id_hub
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.hub_cloud_run_netbox_sa.email}"
}

# connector

resource "google_vpc_access_connector" "hub_eu_connector" {
  project       = var.project_id_hub
  region        = local.hub_eu_region
  name          = "${local.SERVICE_NAME}-connector"
  ip_cidr_range = local.hub_eu_vpc_connector_range1
  network       = module.hub_vpc.self_link
  min_instances = 2
  max_instances = 3
}

# instance

module "hub_cloud_run_netbox" {
  source          = "../../modules/cloud-run-v2"
  project_id      = var.project_id_hub
  name            = local.SERVICE_NAME
  region          = local.hub_eu_region
  iam             = local.cloud_run_users_iam
  service_account = module.hub_cloud_run_netbox_sa.email

  containers = {
    netbox = {
      image = local.NET_BOX_IMAGE
      ports = {
        netbox = { name = "http1", container_port = 8080 }
      }
      env = {
        ALLOWED_HOSTS        = "unix"
        DB_HOST              = local.DB_HOST
        DB_PORT              = local.DB_PORT
        DB_NAME              = local.DB_NAME
        DB_USER              = local.DB_USER
        REDIS_HOST           = local.REDIS_HOST
        REDIS_PORT           = local.redis_port
        REDIS_DATABASE       = local.REDIS_DATABASE
        REDIS_CACHE_HOST     = local.REDIS_HOST
        REDIS_CACHE_PORT     = local.redis_port
        REDIS_CACHE_DATABASE = local.REDIS_CACHE_DATABASE
        DB_WAIT_DEBUG        = 1
        HOSTNAME             = "0.0.0.0"
      }
      env_from_key = {
        DB_PASSWORD          = { secret = google_secret_manager_secret.hub_netbox_secrets["DB_PASSWORD"].name, version = local.SECRET_VERSION }
        REDIS_PASSWORD       = { secret = google_secret_manager_secret.hub_netbox_secrets["REDIS_PASSWORD"].name, version = local.SECRET_VERSION }
        REDIS_CACHE_PASSWORD = { secret = google_secret_manager_secret.hub_netbox_secrets["REDIS_CACHE_PASSWORD"].name, version = local.SECRET_VERSION }
        SUPERUSER_PASSWORD   = { secret = google_secret_manager_secret.hub_netbox_secrets["SUPERUSER_PASSWORD"].name, version = local.SECRET_VERSION }
        EMAIL_PASSWORD       = { secret = google_secret_manager_secret.hub_netbox_secrets["EMAIL_PASSWORD"].name, version = local.SECRET_VERSION }
        SECRET_KEY           = { secret = google_secret_manager_secret.hub_netbox_secrets["SECRET_KEY"].name, version = local.SECRET_VERSION }
      }
    }
  }
  revision = {
    max_instance_count = 100
    vpc_access = {
      connector = google_vpc_access_connector.hub_eu_connector.id
      egress    = "ALL_TRAFFIC"
    }
  }
  deletion_protection = false
}
