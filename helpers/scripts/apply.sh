#!/bin/bash

terraform_plan() {
  terraform fmt
  terraform init
  terraform plan -out=tfplan -lock=false
}

terraform_apply() {
  terraform apply -auto-approve -parallelism=50 "tfplan"
  rm -f tfplan
}

tfswitch 1.8.3 && source ~/.profile
terraform_plan
terraform_apply
