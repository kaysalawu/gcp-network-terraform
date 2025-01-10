
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

variable "subnetwork" {
  description = "Subnetwork used for the forwarding rule."
  type        = string
}

variable "proxy_subnetwork" {
  description = "Proxy Subnetwork used for the forwarding rule."
  type        = list(any)
  default     = []
}

variable "region" {
  description = "GCP region used for resources."
  type        = string
}

variable "frontend" {
  type = object({
    address = string
    ssl = object({
      self_cert = bool
      domains   = list(string)
    })
  })
}

variable "protocol" {
  description = "IP protocol used, defaults to TCP."
  type        = string
  default     = "TCP"
}

variable "address" {
  description = "Optional IP address used for the forwarding rule."
  type        = string
  default     = null
}

variable "port_range" {
  description = "Port used for forwarding rule."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels set on resources."
  type        = map(string)
  default     = {}
}

variable "service_label" {
  description = "Optional prefix of the fully qualified forwarding rule name."
  type        = string
  default     = null
}

variable "url_map" {
  description = "url map"
  type        = string
}
