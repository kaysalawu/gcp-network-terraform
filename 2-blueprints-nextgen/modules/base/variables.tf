
variable "prefix" {
  description = "Prefix to be used for all resources"
  type        = string
}

variable "project_id" {
  description = "The project ID to deploy into"
  type        = string
}

# variable "vpc_config" {
#   description = "Configuration for the VPC"
#   type = list(object({
#     subnets = optional(map(object({
#       region             = string
#       ip_cidr_range      = string
#       secondary_ip_range = optional(map(string))
#       purpose            = string
#       role               = string
#     })), {})
#   }))
#   routing_mode = optional(string, "GLOBAL")
#   mtu          = optional(number, 1460)

#   auto_create_subnetworks         = optional(bool, false)
#   delete_default_routes_on_create = optional(bool, false)
# }


