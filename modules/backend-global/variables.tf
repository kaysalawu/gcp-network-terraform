
variable "project_id" {
  description = "Project id where resources will be created."
  type        = string
}

variable "prefix" {
  description = "Prefix used for all resources."
  type        = string
}

variable "network" {
  description = "Network used for resources."
  type        = string
}

variable "labels" {
  description = "Labels set on resources."
  type        = map(string)
  default     = {}
}

variable "backend_services_mig" {
  description = "MIG backend services map."
  type = map(object({
    port_name       = string
    security_policy = string
    enable_cdn      = bool
    backends        = list(any)
    health_check_config = object({
      check   = map(any)    # actual health check block attributes
      config  = map(number) # interval, thresholds, timeout
      logging = bool
    })
  }))
  default = {}
}

variable "backend_services_neg" {
  description = "NEG backend services map."
  type = map(object({
    port            = number
    security_policy = string
    enable_cdn      = bool
    backends        = list(any)
    health_check_config = object({
      check   = map(any)    # actual health check block attributes
      config  = map(number) # interval, thresholds, timeout
      logging = bool
    })
  }))
  default = {}
}

variable "backend_services_psc_neg" {
  description = "PSC NEG backend services map."
  type = map(object({
    port     = number
    backends = list(any)
  }))
  default = {}
}
