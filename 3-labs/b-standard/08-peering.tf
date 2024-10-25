
# vpc peering
####################################################---

# hub1 <--> spoke1

module "hub_spoke1" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-peering?ref=v34.1.0"
  prefix        = "${local.hub_prefix}--spoke1"
  stack_type    = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
  local_network = module.hub_vpc.self_link
  peer_network  = module.spoke1_vpc.self_link
  routes_config = {
    local  = { import = true, export = true }
    remote = { import = true, export = true }
  }
}

# hub1 <--> spoke2

module "hub_spoke2" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-peering?ref=v34.1.0"
  prefix        = "${local.hub_prefix}--spoke2"
  stack_type    = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
  local_network = module.hub_vpc.self_link
  peer_network  = module.spoke2_vpc.self_link
  routes_config = {
    local  = { import = true, export = true }
    remote = { import = true, export = true }
  }
  depends_on = [
    module.hub_spoke1
  ]
}


# spoke1 <--> spoke2

module "spoke1_spoke2" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-peering?ref=v34.1.0"
  prefix        = "${local.spoke1_prefix}--spoke2"
  stack_type    = local.enable_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"
  local_network = module.spoke1_vpc.self_link
  peer_network  = module.spoke2_vpc.self_link
  routes_config = {
    local  = { import = true, export = true }
    remote = { import = true, export = true }
  }
  depends_on = [
    module.hub_spoke1,
    module.hub_spoke2
  ]
}
