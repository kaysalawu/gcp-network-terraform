#!/bin/bash

gcloud config set project ${PROJECT}
gcloud -q auth configure-docker ${GCR_HOST}
docker pull ${DOCKER_IMAGE}
docker tag ${DOCKER_IMAGE} ${IMAGE_REPO}
docker push ${IMAGE_REPO}
