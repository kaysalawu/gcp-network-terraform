#!/bin/bash

gcloud alpha -q network-connectivity hubs delete ${HUB_NAME} \
--project=${PROJECT_ID}
