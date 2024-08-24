#!/bin/bash

gcloud beta compute security-policies create ${POLICY_NAME} \
--project=${PROJECT_ID} \
--description=CLOUD_ARMOR_EDGE \
--type=${POLICY_TYPE}
