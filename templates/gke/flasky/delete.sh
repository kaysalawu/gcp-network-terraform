#!/bin/bash

gcloud config set project ${PROJECT_ID}
gcloud auth configure-docker
gcloud config set compute/region ${REGION}
gcloud container clusters get-credentials ${CLUSTER} --region=${REGION}
kubectl delete -f manifests
