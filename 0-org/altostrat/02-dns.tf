
# public dns

resource "google_dns_managed_zone" "salawu_altostrat" {
  project     = var.project_id_hub
  name        = "${local.prefix}salawu-altostrat"
  dns_name    = "salawu.altostrat.com."
  description = "Altostrat Public Second Level Domain"
  labels = {
    owner = "salawu"
    lab   = "${local.prefix}common"
  }
  lifecycle {
    prevent_destroy = true
  }
}
