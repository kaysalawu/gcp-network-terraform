
# public dns

resource "google_dns_managed_zone" "cloudtuple" {
  project     = var.project_id_hub
  name        = "${local.prefix}public-cloudtuple"
  dns_name    = "cloudtuple.com."
  description = "Cloudtuple Public Second Level Domain"
  labels = {
    owner = "salawu"
    lab   = "${local.prefix}common"
  }
  lifecycle {
    prevent_destroy = true
  }
}
