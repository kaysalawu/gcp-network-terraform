
# onprem

module "onprem" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/project?ref=v33.0.0"
  billing_account = var.billing_account_id
  name            = "onprem-lab"
  prefix          = var.prefix
  parent          = "organizations/${var.organization_id}"
  services        = local.project_services
}

# hub

module "hub" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/project?ref=v33.0.0"
  billing_account = var.billing_account_id
  name            = "hub-lab"
  prefix          = var.prefix
  parent          = "organizations/${var.organization_id}"
  services        = local.project_services
}

# host

module "host" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/project?ref=v33.0.0"
  billing_account = var.billing_account_id
  name            = "host-lab"
  prefix          = var.prefix
  parent          = "organizations/${var.organization_id}"
  services        = local.project_services
}

# spoke1

module "spoke1" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/project?ref=v33.0.0"
  billing_account = var.billing_account_id
  name            = "spoke1-lab"
  prefix          = var.prefix
  parent          = "organizations/${var.organization_id}"
  services        = local.project_services
}

# spoke2

module "spoke2" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/project?ref=v33.0.0"
  billing_account = var.billing_account_id
  name            = "spoke2-lab"
  prefix          = var.prefix
  parent          = "organizations/${var.organization_id}"
  services        = local.project_services
}
