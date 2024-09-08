
variable "prefix" {
  description = "prefix used for all resources"
  default     = "a"
}

variable "organization_id" {
  description = "organization id"
  default     = null
}

variable "folder_id" {
  description = "folder id"
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

