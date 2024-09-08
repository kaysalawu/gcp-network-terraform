
terraform {
  backend "gcs" {
    bucket = "bkt-gcp-network-terraform"
    prefix = "1-labs/a-standard"
  }
}
