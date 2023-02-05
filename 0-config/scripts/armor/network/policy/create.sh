
gcloud alpha compute security-policies create ${POLICY_NAME} \
--project=${PROJECT_ID} \
--type=CLOUD_ARMOR_NETWORK \
--region=${REGION}
