#!/bin/bash

cat <<EOF > ${POLICY_FILE_DIR}/${POLICY_FILE_NAME}
${POLICY_FILE_YAML}
EOF

gcloud compute security-policies create ${POLICY_NAME} \
--project ${PROJECT_ID} \
--file-format=yaml \
--file-name=${POLICY_FILE_DIR}/${POLICY_FILE_NAME}

# does not support updating rules
# can be used for one time upload of all rules inside the YAML
