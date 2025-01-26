#!bin/bash

PROJECT_ID=prj-hub-lab
LOCATION=europe-west2
CLUSTER_NAME=g1-hub-cluster
CURRENT_DIR=$(pwd)

gcloud container clusters get-credentials $CLUSTER_NAME --region "$LOCATION-b" --project=$PROJECT_ID
