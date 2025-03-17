
variable "vpc_name" {
  description = "The name of the VPC."
  type        = string
}

variable "enable_restricted" {
  description = "Enable restricted API access."
  type        = bool
  default     = false
}

variable "secure_tags" {
  description = "The secure tags for egress internet."
  type = object({
    egress_internet  = optional(string, null)
    egress_private   = optional(string, null)
    ingress_internet = optional(string, null)
    ingress_private  = optional(string, null)
  })
}
