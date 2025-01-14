
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

variable "aura_env_name" {
  description = "aura environment name"
}

variable "neo4j_dbid" {
  description = "neo4j database id"
}

variable "neo4j_db_username" {
  description = "neo4j database username"
}

variable "neo4j_db_password" {
  description = "neo4j database password"
}
