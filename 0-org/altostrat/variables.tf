
variable "organization_id" {
  description = "organization id"
}

variable "project_id_hub" {
  description = "project id for hub"
}

variable "project_id_host" {
  description = "host project id"
}

variable "project_id_spoke1" {
  description = "project id for spoke1"
}

variable "project_id_spoke2" {
  description = "project id for spoke2"
}

variable "public_key_path" {
  description = "Path to SSH public key to be attached to cloud instances"
}

variable "module_depends_on" {
  type    = any
  default = null
}

variable "email" {
  description = "email for acme account resgistration"
}
