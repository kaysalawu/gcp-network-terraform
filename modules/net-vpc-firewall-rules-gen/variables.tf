
variable "vpc_name" {
  description = "The name of the VPC."
  type        = string
}

variable "enable_restricted" {
  description = "Enable restricted API access."
  type        = bool
  default     = false
}
