
variable "prefix" {
  description = "prefix used for all resources"
  default     = "g4"
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
  description = "project id"
}

variable "neo4j_db_uri" {
  description = "neo4j database uri"
}

variable "neo4j_db_username" {
  description = "neo4j database username"
}

variable "neo4j_db_password" {
  description = "neo4j database password"
}
