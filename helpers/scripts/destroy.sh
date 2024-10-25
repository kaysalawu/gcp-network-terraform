#!/bin/bash

terraform_destroy() {
  terraform init
  terraform destroy -auto-approve -lock=false -parallelism=50
}

tfswitch 1.8.3 && source ~/.profile
terraform_destroy
if [ $? -eq 0 ]; then
    rm -rf .terraform
    rm .terraform.*
    rm terraform.*
else
    return 1
fi

