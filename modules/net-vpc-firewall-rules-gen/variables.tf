
variable "vpc_name" {
  description = "The name of the VPC."
  type        = string
}

variable "enable_restricted" {
  description = "Enable restricted API access."
  type        = bool
  default     = false
}

variable "target_tags" {
  description = "The secure tags for egress internet."
  type = object({
    egress_internet  = optional(string, "egress-internet")
    egress_private   = optional(string, "egress-private")
    ingress_internet = optional(string, "ingress-internet")
    ingress_private  = optional(string, "ingress-private")
  })
  default = {
    egress_internet  = "egress-internet"
    egress_private   = "egress-private"
    ingress_internet = "ingress-internet"
    ingress_private  = "ingress-private"
  }
}
