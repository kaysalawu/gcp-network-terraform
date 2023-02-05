
gcloud -q compute network-endpoint-groups delete ${NEG_NAME} \
--project=${PROJECT_ID} \
--zone=${ZONE}
