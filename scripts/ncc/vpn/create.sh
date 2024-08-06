#!/bin/bash

gcloud alpha network-connectivity spokes create ${SPOKE_NAME} \
--project=${PROJECT_ID} \
--hub=${HUB_NAME} \
--description=${SPOKE_NAME} \
--vpn-tunnel=${TUNNEL1},${TUNNEL2} \
--region=${REGION}
