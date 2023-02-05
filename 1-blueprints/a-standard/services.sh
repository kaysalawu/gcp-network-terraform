#!/bin/bash

services=(
compute.googleapis.com
dns.googleapis.com
cloudresourcemanager.googleapis.com
iam.googleapis.com
servicedirectory.googleapis.com
servicenetworking.googleapis.com
orgpolicy.googleapis.com
)

PROJECT=$1

function enable_services() {
  for service in "${services[@]}"; do
    if [[ $(gcloud services list --project $PROJECT --format="value(config.name)" \
                                  --filter="config.name:$service" 2>&1) != \
                                  "$service" ]]; then
      echo "Enabling $service"
      gcloud services enable $service --project $PROJECT
    else
      echo "$service is already enabled"
    fi
  done
}

time enable_services
