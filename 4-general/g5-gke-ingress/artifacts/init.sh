#!bin/bash

PROJECT_ID=prj-hub-lab
LOCATION=europe-west2
CLUSTER_NAME1=g5-hub-eu-cluster
CLUSTER_NAME2=g5-hub-us-cluster
CURRENT_DIR=$(pwd)

gcloud container clusters get-credentials $CLUSTER_NAME1 --region "$LOCATION-b" --project=$PROJECT_ID
