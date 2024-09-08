
variable "prefix" {
  description = "The prefix to use for the project"
  default     = "prj"
}

variable "organization_id" {
  description = "The organization id to create the project in"
  default     = null
}

variable "folder_id" {
  description = "The folder id to create the project in"
  default     = null
}

variable "billing_account_id" {
  description = "The billing account id to associate with the project"
}
