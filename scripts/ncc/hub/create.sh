#!/bin/bash

#----------------------------
echo -e "\n enable: api\n"
gcloud services enable \
--project=${PROJECT_ID} \
networkconnectivity.googleapis.com

gcloud alpha network-connectivity hubs create ${HUB_NAME} \
--description=${HUB_NAME} \
--project=${PROJECT_ID}
