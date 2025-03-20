
locals {
  egress_rules = {
    # ipv4
    #*************************
    "${var.vpc_name}-4000-e-a-all-all-egress-internet" = {
      description = "Allow internet egress from tagged resources."
      priority    = 4000
      action      = "allow"
      match = {
        destination_ranges = ["0.0.0.0/0", ]
        layer4_configs     = [{ protocol = "all" }]
      }
      target_tags = [
        var.secure_tags.egress_internet,
      ]
    }
    "${var.vpc_name}-4100-e-a-google-apis-all-tcp-443" = {
      description = (var.enable_restricted ?
        "Allow egress to restricted.googleapis on TCP/443." :
        "Allow egress to private.googleapis on TCP/443."
      )
      priority = 4100
      action   = "allow"
      match = {
        destination_ranges = (var.enable_restricted ?
          local.netblocks_restricted_api :
          local.netblocks_private_api
        )
        layer4_configs = [{ protocol = "tcp", ports = ["443"] }]
      }
    }
    "${var.vpc_name}-4200-e-a-all-all-all" = {
      description = "Allow all egress to specified IP ranges."
      priority    = 4200
      action      = "allow"
      match = {
        destination_ranges = local.netblocks_internal
        layer4_configs     = [{ protocol = "all" }]
      }
      target_tags = [
        var.secure_tags.egress_private,
      ]
    }
    # ipv6
    #*************************
    "${var.vpc_name}-6000-e-a-all-all-egress-internet-ipv6" = {
      description = "(IPv6) Allow internet egress from tagged resources."
      priority    = 6000
      action      = "allow"
      match = {
        destination_ranges = ["0::/0", ]
        layer4_configs     = [{ protocol = "all" }]
      }
      target_tags = [
        var.secure_tags.egress_internet,
      ]
    }
    "${var.vpc_name}-6100-e-a-google-apis-all-tcp-443-ipv6" = {
      description = (var.enable_restricted ?
        "(IPv6) Allow egress to restricted.googleapis on TCP/443." :
        "(IPv6) Allow egress to private.googleapis on TCP/443."
      )
      priority = 6100
      action   = "allow"
      match = {
        destination_ranges = (var.enable_restricted ?
          local.netblocks_restricted_api_ipv6 :
          local.netblocks_private_api_ipv6
        )
        layer4_configs = [{ protocol = "tcp", ports = ["443"] }]
      }
    }
    "${var.vpc_name}-6200-e-a-all-all-all-ipv6" = {
      description = "(IPv6) Allow all egress to specified IP ranges."
      priority    = 6200
      action      = "allow"
      match = {
        destination_ranges = local.netblocks_internal_ipv6
        layer4_configs     = [{ protocol = "all" }]
      }
      target_tags = [
        var.secure_tags.egress_private,
      ]
    }
  }
  ingress_rules = {
    # ipv4
    #*************************
    "${var.vpc_name}-4001-i-a-custom-internet-ingress" = {
      description = "Allow internet ingress to specific ports."
      priority    = 4001
      action      = "allow"
      match = {
        source_ranges = ["0.0.0.0/0", ]
        layer4_configs = [
          { protocol = "tcp", ports = values(local.ports_accessible_from_internet) },
        ]
      }
      target_tags = [
        var.secure_tags.ingress_internet,
      ]
    }
    "${var.vpc_name}-4201-i-a-all-private" = {
      description = "Allow all ingress from specified ranges."
      priority    = 4201
      action      = "allow"
      match = {
        source_ranges  = local.netblocks_internal
        layer4_configs = [{ protocol = "all" }]
      }
      target_tags = [
        var.secure_tags.ingress_private,
      ]
    }
    # "${var.vpc_name}-4300-i-a-tcp-all-iap" = {
    #   description    = "Allow IAP ingress traffic."
    #   priority       = 4300
    #   action         = "allow"
    #   enable_logging = true
    #   match = {
    #     source_ranges  = local.netblocks_iap
    #     layer4_configs = [{ protocol = "all", ports = [] }]
    #   }
    # }
    "${var.vpc_name}-4400-i-a-all-all-gfe" = {
      description = "Allow all GFE ingress traffic."
      priority    = 4400
      action      = "allow"
      match = {
        source_ranges  = local.netblocks_gfe
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
    }
    "${var.vpc_name}-4500-i-a-tcp-22-ssh" = {
      description    = "Allow SSH ingress traffic."
      priority       = 4500
      action         = "allow"
      enable_logging = true
      match = {
        source_ranges  = ["0.0.0.0/0", ]
        layer4_configs = [{ protocol = "tcp", ports = ["22"] }]
      }
    }
    "${var.vpc_name}-4600-i-a-mixed-vpn" = {
      description = "Allow UDP:500/4500 and ESP ingress traffic."
      priority    = 4600
      action      = "allow"
      match = {
        source_ranges = ["0.0.0.0/0", ]
        layer4_configs = [
          { protocol = "udp", ports = ["500", "4500", ] },
          { protocol = "esp", ports = [] }
        ]
      }
    }
    "${var.vpc_name}-4700-i-a-all-dns" = {
      description    = "Allow Google DNS egress proxy traffic."
      priority       = 4700
      action         = "allow"
      enable_logging = true
      match = {
        source_ranges  = local.netblocks_dns
        layer4_configs = [{ protocol = "all" }]
      }
    }
    # ipv6
    #*************************
    "${var.vpc_name}-6001-i-a-custom-internet-ingress-ipv6" = {
      description = "(IPv6) Allow internet ingress to specific ports."
      priority    = 6001
      action      = "allow"
      match = {
        source_ranges = ["0::/0", ]
        layer4_configs = [
          { protocol = "tcp", ports = values(local.ports_accessible_from_internet) },
        ]
      }
      target_tags = [
        var.secure_tags.ingress_internet,
      ]
    }
    "${var.vpc_name}-6201-i-a-all-private-ipv6" = {
      description = "(IPv6) Allow all ingress from specified ranges."
      priority    = 6201
      action      = "allow"
      match = {
        source_ranges  = local.netblocks_internal_ipv6
        layer4_configs = [{ protocol = "all" }]
      }
      target_tags = [
        var.secure_tags.ingress_private,
      ]
    }
    # "${var.vpc_name}-6300-i-a-tcp-all-iap-ipv6" = {
    #   description    = "Allow IAP ingress traffic."
    #   priority       = 6300
    #   action         = "allow"
    #   enable_logging = true
    #   match = {
    #     source_ranges  = local.netblocks_iap_ipv6
    #     layer4_configs = [{ protocol = "all", ports = [] }]
    #   }
    # }
    "${var.vpc_name}-6400-i-a-all-all-gfe-ipv6" = {
      description = "(IPv6) Allow all GFE ingress traffic."
      priority    = 6400
      action      = "allow"
      match = {
        source_ranges  = local.netblocks_gfe_ipv6
        layer4_configs = [{ protocol = "all", ports = [] }]
      }
    }
    "${var.vpc_name}-6500-i-a-tcp-22-ssh-ipv6" = {
      description    = "(IPv6) Allow SSH ingress traffic."
      priority       = 6500
      action         = "allow"
      enable_logging = true
      match = {
        source_ranges  = ["0::/0", ]
        layer4_configs = [{ protocol = "tcp", ports = ["22"] }]
      }
    }
    "${var.vpc_name}-6600-i-a-mixed-vpn-ipv6" = {
      description = "(IPv6) Allow UDP:500/4500 and ESP ingress traffic."
      priority    = 6600
      action      = "allow"
      match = {
        source_ranges = ["0::/0", ]
        layer4_configs = [
          { protocol = "udp", ports = ["500", "4500", ] },
          { protocol = "esp", ports = [] }
        ]
      }
    }
  }
}
