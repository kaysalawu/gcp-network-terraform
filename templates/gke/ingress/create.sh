#!/bin/bash

gcloud config set project ${PROJECT_ID}
gcloud -q auth configure-docker ${GCR_HOST}
gcloud config set compute/region ${REGION}
gcloud container clusters get-credentials ${CLUSTER} --region=${REGION}
gcloud builds submit --tag ${IMAGE_REPO} .
kubectl apply -f manifests
