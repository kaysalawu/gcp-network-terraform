#!/bin/bash

gcloud -q beta compute security-policies delete ${POLICY_NAME} \
--project=${PROJECT_ID}
