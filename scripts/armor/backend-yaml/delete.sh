#!/bin/bash

gcloud -q compute security-policies delete ${POLICY_NAME} \
--project ${PROJECT_ID}

rm ${POLICY_FILE_DIR}/${POLICY_FILE_NAME}
