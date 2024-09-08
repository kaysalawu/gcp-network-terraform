#!/bin/bash

tfswitch 1.8.3 && source ~/.profile
rm -rf .terraform
rm .terraform.lock.hcl
rm terraform.tfstate.backup
terraform init
