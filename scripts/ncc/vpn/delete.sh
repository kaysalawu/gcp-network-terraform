#!/bin/bash

gcloud alpha -q network-connectivity spokes delete ${SPOKE_NAME} \
--project=${PROJECT_ID} \
--region=${REGION}
