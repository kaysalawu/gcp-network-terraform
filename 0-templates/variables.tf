
variable "organization_id" {
  description = "organization id"
  default     = null
}

variable "project_id_hub" {
  description = "hub project id"
}

variable "project_id_host" {
  description = "host project id"
}

variable "project_id_spoke1" {
  description = "spoke1 project id (service project id attached to the host project"
}

variable "project_id_spoke2" {
  description = "spoke2 project id (standalone project)"
}

variable "project_id_onprem" {
  description = "onprem project id (for onprem site1 and site2)"
}

variable "machine_type" {
  description = "vm instance size"
  type        = string
  default     = "e2-small"
}

variable "image_debian" {
  description = "vm instance image"
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "image_ubuntu" {
  description = "vm instance image"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "image_cos" {
  description = "container optimized image"
  type        = string
  default     = "cos-cloud/cos-stable"
}

variable "disk_type" {
  description = "disk type"
  type        = string
  default     = "pd-ssd"
}

variable "disk_size" {
  description = "disk size"
  type        = string
  default     = "20"
}

variable "bgp_range" {
  description = "bgp interface ip cidr ranges."
  type        = map(string)
  default = {
    cidr1  = "169.254.101.0/30"
    cidr2  = "169.254.102.0/30"
    cidr3  = "169.254.103.0/30"
    cidr4  = "169.254.104.0/30"
    cidr5  = "169.254.105.0/30"
    cidr6  = "169.254.106.0/30"
    cidr7  = "169.254.107.0/30"
    cidr8  = "169.254.108.0/30"
    cidr9  = "169.254.109.0/30"
    cidr10 = "169.254.110.0/30"
  }
}

variable "gre_range" {
  description = "gre interface ip cidr ranges."
  type        = map(string)
  default = {
    cidr1 = "172.16.1.0/24"
    cidr2 = "172.16.2.0/24"
    cidr3 = "172.16.3.0/24"
    cidr4 = "172.16.4.0/24"
    cidr5 = "172.16.5.0/24"
    cidr6 = "172.16.6.0/24"
    cidr7 = "172.16.7.0/24"
    cidr8 = "172.16.8.0/24"
  }
}

variable "image_vyos" {
  description = "vyos image from gcp marketplace"
  type        = string
  default     = "https://www.googleapis.com/compute/v1/projects/sentrium-public/global/images/vyos-1-3-0"
}

variable "image_panos" {
  description = "palo alto image from gcp marketplace"
  type        = string
  default     = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/vmseries-bundle1-810"
}

variable "shielded_config" {
  description = "Shielded VM configuration of the instances."
  default = {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}
